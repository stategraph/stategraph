/**
 * Tests for states adapter utilities
 * Run with: npx tsx lib/states/adapter.test.ts
 */

import {
  stateToTableRow,
  stateToDetail,
  sortTableRows,
  type StateTableRow,
  type StateOverview,
} from './adapter';
import type { State, StateSummary, Transaction } from '@/lib/api/client';

console.log('🧪 Testing States Adapter\n');
console.log('='.repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

// ============================================================================
// Mock Data
// ============================================================================

const mockState: State = {
  id: 'state-1',
  name: 'production-us-east-1',
  created_at: '2025-12-01T10:00:00Z',
  updated_at: '2025-12-15T14:30:00Z',
  workspace: 'production',
  group_id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
};

// StateSummary / Transaction still feed stateToDetail (converted separately, #1087).
const mockSummary: StateSummary = {
  resources: 45,
  instances: 52,
  modules: 8,
  providers: 3,
  edges: 120,
};

const mockTransaction: Transaction = {
  id: 'tx-1',
  state: 'state-1',
  created_at: '2025-12-15T14:00:00Z',
  completed_at: '2025-12-15T14:05:00Z',
  created_by: 'user-1',
  state_names: [],
  params: {},
  tags: {},
};

// Recent transaction (<1 hour ago, incomplete)
const mockIncompleteTransaction: Transaction = {
  id: 'tx-2',
  state: 'state-1',
  created_at: new Date(Date.now() - 30 * 60 * 1000).toISOString(), // 30 minutes ago
  created_by: 'user-1',
  state_names: [],
  params: {},
  tags: {},
};

// StateOverview (the MQL-derived aggregates) feeds stateToTableRow.
const mockOverview: StateOverview = {
  instances: 52,
  edges: 120,
  last_tx_created_at: '2025-12-15T14:00:00Z',
  last_tx_completed_at: '2025-12-15T14:05:00Z',
  last_tx_status: 'committed',
};

const mockOverviewNoTx: StateOverview = {
  instances: 52,
  edges: 120,
  last_tx_created_at: null,
  last_tx_completed_at: null,
  last_tx_status: null,
};

const mockSmallOverview: StateOverview = {
  instances: 12,
  edges: 25,
  last_tx_created_at: null,
  last_tx_completed_at: null,
  last_tx_status: null,
};

const mockLargeOverview: StateOverview = {
  instances: 250,
  edges: 500,
  last_tx_created_at: null,
  last_tx_completed_at: null,
  last_tx_status: null,
};

// Open (incomplete) transaction >1 hour ago -> Locked
const mockOverviewOldOpen: StateOverview = {
  instances: 52,
  edges: 120,
  last_tx_created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
  last_tx_completed_at: null,
  last_tx_status: 'open',
};

// Open (incomplete) transaction <1 hour ago -> Healthy
const mockOverviewRecentOpen: StateOverview = {
  instances: 52,
  edges: 120,
  last_tx_created_at: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
  last_tx_completed_at: null,
  last_tx_status: 'open',
};

// ============================================================================
// Tests
// ============================================================================

const tests: TestCase[] = [
  // stateToTableRow tests
  {
    name: 'stateToTableRow - Basic transformation',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverview);
      return (
        row.id === 'state-1' &&
        row.name === 'production-us-east-1' &&
        row.resourceCount === 52 &&
        row.status === 'Healthy'
      );
    },
  },
  {
    name: 'stateToTableRow - Workspace field',
    fn: () => {
      const row = stateToTableRow(mockState);
      return row.workspace === 'production';
    },
  },
  {
    name: 'stateToTableRow - Workspace defaults to "default"',
    fn: () => {
      const stateNoWorkspace = { ...mockState, workspace: '' };
      const row = stateToTableRow(stateNoWorkspace);
      return row.workspace === 'default';
    },
  },
  {
    name: 'stateToTableRow - Group ID field',
    fn: () => {
      const row = stateToTableRow(mockState);
      return row.groupId === mockState.group_id;
    },
  },
  {
    name: 'stateToTableRow - Blast radius small',
    fn: () => {
      const row = stateToTableRow(mockState, mockSmallOverview);
      return row.blastRadius.size === 'Small' && row.blastRadius.count === 25;
    },
  },
  {
    name: 'stateToTableRow - Blast radius medium',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverview);
      return row.blastRadius.size === 'Medium' && row.blastRadius.count === 120;
    },
  },
  {
    name: 'stateToTableRow - Blast radius large',
    fn: () => {
      const row = stateToTableRow(mockState, mockLargeOverview);
      return row.blastRadius.size === 'Large' && row.blastRadius.count === 500;
    },
  },
  {
    name: 'stateToTableRow - Last transaction with completed',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverview);
      return (
        row.lastTransaction !== null &&
        row.lastTransaction.type === 'Apply' &&
        row.lastTransaction.timestamp === '2025-12-15T14:00:00Z'
      );
    },
  },
  {
    name: 'stateToTableRow - Last transaction null when no transaction',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverviewNoTx);
      return row.lastTransaction === null;
    },
  },
  {
    name: 'stateToTableRow - Status healthy by default',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverview);
      return row.status === 'Healthy';
    },
  },
  {
    name: 'stateToTableRow - Status locked when old incomplete transaction',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverviewOldOpen);
      return row.status === 'Locked';
    },
  },
  {
    name: 'stateToTableRow - Status healthy when recent incomplete transaction',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverviewRecentOpen);
      return row.status === 'Healthy';
    },
  },
  {
    name: 'stateToTableRow - Raw data preserved',
    fn: () => {
      const row = stateToTableRow(mockState, mockOverview);
      return (
        row._raw.state === mockState &&
        row._raw.overview === mockOverview
      );
    },
  },

  // stateToDetail tests
  {
    name: 'stateToDetail - Basic transformation',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary, [mockTransaction]);
      return (
        detail.id === 'state-1' &&
        detail.name === 'production-us-east-1' &&
        detail.resourceCount === 52 &&
        detail.status === 'Healthy'
      );
    },
  },
  {
    name: 'stateToDetail - Context object structure',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary);
      return (
        detail.context.workspace === 'production' &&
        detail.context.groupId === 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
      );
    },
  },
  {
    name: 'stateToDetail - Recent activity empty when no transactions',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary, []);
      return detail.recentActivity.length === 0;
    },
  },
  {
    name: 'stateToDetail - Recent activity populated',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary, [mockTransaction]);
      return (
        detail.recentActivity.length === 1 &&
        detail.recentActivity[0].type === 'Apply' &&
        detail.recentActivity[0].result === 'Success'
      );
    },
  },
  {
    name: 'stateToDetail - Recent activity limited to 5',
    fn: () => {
      const manyTxs = Array(10).fill(mockTransaction).map((tx, i) => ({ ...tx, id: `tx-${i}` }));
      const detail = stateToDetail(mockState, mockSummary, manyTxs);
      return detail.recentActivity.length === 5;
    },
  },
  {
    name: 'stateToDetail - Last successful apply found',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary, [mockTransaction]);
      return detail.lastSuccessfulApply === '2025-12-15T14:05:00Z';
    },
  },
  {
    name: 'stateToDetail - Last successful apply undefined when no completed',
    fn: () => {
      const detail = stateToDetail(mockState, mockSummary, [mockIncompleteTransaction]);
      return detail.lastSuccessfulApply === undefined;
    },
  },

  // Resource count consistency regression tests
  {
    name: 'stateToTableRow - resourceCount uses instances (count consistency)',
    fn: () => {
      // Regression: resourceCount must use the instance count (actual
      // infrastructure objects) so counts match across all UI surfaces.
      const overview: StateOverview = {
        instances: 48,
        edges: 80,
        last_tx_created_at: null,
        last_tx_completed_at: null,
        last_tx_status: null,
      };
      const row = stateToTableRow(mockState, overview);
      return row.resourceCount === 48;
    },
  },
  {
    name: 'stateToDetail - resourceCount uses instances not resources (count consistency)',
    fn: () => {
      const summary: StateSummary = {
        resources: 46,
        instances: 48,
        modules: 5,
        providers: 2,
        edges: 80,
      };
      const detail = stateToDetail(mockState, summary);
      return detail.resourceCount === 48;  // Must be instances, not resources
    },
  },
  {
    name: 'stateToTableRow - resourceCount 0 when no overview',
    fn: () => {
      const row = stateToTableRow(mockState);
      return row.resourceCount === 0;
    },
  },

  // sortTableRows tests
  {
    name: 'sortTableRows - Sort by name ascending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow({ ...mockState, name: 'zebra' }),
        stateToTableRow({ ...mockState, name: 'alpha' }),
        stateToTableRow({ ...mockState, name: 'beta' }),
      ];
      const sorted = sortTableRows(rows, 'name', 'asc');
      return sorted[0].name === 'alpha' && sorted[2].name === 'zebra';
    },
  },
  {
    name: 'sortTableRows - Sort by name descending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow({ ...mockState, name: 'zebra' }),
        stateToTableRow({ ...mockState, name: 'alpha' }),
        stateToTableRow({ ...mockState, name: 'beta' }),
      ];
      const sorted = sortTableRows(rows, 'name', 'desc');
      return sorted[0].name === 'zebra' && sorted[2].name === 'alpha';
    },
  },
  {
    name: 'sortTableRows - Sort by resourceCount ascending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 100 }),
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 10 }),
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 50 }),
      ];
      const sorted = sortTableRows(rows, 'resourceCount', 'asc');
      return sorted[0].resourceCount === 10 && sorted[2].resourceCount === 100;
    },
  },
  {
    name: 'sortTableRows - Sort by resourceCount descending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 100 }),
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 10 }),
        stateToTableRow(mockState, { ...mockOverviewNoTx, instances: 50 }),
      ];
      const sorted = sortTableRows(rows, 'resourceCount', 'desc');
      return sorted[0].resourceCount === 100 && sorted[2].resourceCount === 10;
    },
  },
  {
    name: 'sortTableRows - Sort by lastTransaction ascending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T14:00:00Z' }),
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T12:00:00Z' }),
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T16:00:00Z' }),
      ];
      const sorted = sortTableRows(rows, 'lastTransaction', 'asc');
      return sorted[0].lastTransaction?.timestamp === '2025-12-15T12:00:00Z' &&
        sorted[2].lastTransaction?.timestamp === '2025-12-15T16:00:00Z';
    },
  },
  {
    name: 'sortTableRows - Sort by lastTransaction descending',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T14:00:00Z' }),
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T12:00:00Z' }),
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T16:00:00Z' }),
      ];
      const sorted = sortTableRows(rows, 'lastTransaction', 'desc');
      return sorted[0].lastTransaction?.timestamp === '2025-12-15T16:00:00Z' &&
        sorted[2].lastTransaction?.timestamp === '2025-12-15T12:00:00Z';
    },
  },
  {
    name: 'sortTableRows - Handle null lastTransaction in sorting',
    fn: () => {
      const rows: StateTableRow[] = [
        stateToTableRow(mockState, mockOverview),
        stateToTableRow(mockState, mockOverviewNoTx), // No transaction
        stateToTableRow(mockState, { ...mockOverview, last_tx_created_at: '2025-12-15T16:00:00Z' }),
      ];
      const sorted = sortTableRows(rows, 'lastTransaction', 'asc');
      // Null should be sorted first (empty string)
      return sorted[0].lastTransaction === null;
    },
  },
];

// Run all tests
tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`✅ PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`❌ FAIL: ${test.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${test.name} (threw error: ${error})`);
    failed++;
  }
});

console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${tests.length} tests`);
