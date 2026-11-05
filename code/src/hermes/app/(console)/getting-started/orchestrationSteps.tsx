"use client";

import { useEffect, useRef, type ReactNode } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Cloud,
  ExternalLink,
  Settings,
  Users,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { CodeBlock } from "@/components/getting-started";
import { useSetupProgress, useStates } from "@/contexts";
import { SETUP_COPY } from "@/lib/getting-started/setup-progress";
import type { VcsProvider } from "@/lib/vcs/links";
import {
  CREDENTIAL_CARDS,
  DEMO_REPOSITORIES,
  DOC_LINKS,
  GITHUB_WORKFLOW_LANGUAGE,
  GITHUB_WORKFLOW_PATH,
  GITHUB_WORKFLOW_YAML,
  GITLAB_PIPELINE_PATH,
  GITLAB_PIPELINE_YAML,
  ORCHESTRATION_COPY,
} from "@/lib/getting-started/orchestration-constants";

const COPY = ORCHESTRATION_COPY;

export function StepHeading({ title, lead }: { title: string; lead: string }) {
  const headingRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    headingRef.current?.focus();
  }, []);

  return (
    <div className="space-y-3">
      <h1
        ref={headingRef}
        tabIndex={-1}
        className="text-2xl font-semibold tracking-tight text-[var(--sg-text)] outline-none sm:text-3xl lg:text-4xl"
      >
        {title}
      </h1>
      <p className="max-w-prose text-base text-[var(--sg-text-muted)] lg:text-lg">{lead}</p>
    </div>
  );
}

export function StepFooter({
  onBack,
  children,
}: {
  onBack?: () => void;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-between">
      {onBack ? (
        <Button variant="outline" onClick={onBack} className="w-full sm:w-auto">
          <ArrowLeft className="h-4 w-4" /> {COPY.common.back}
        </Button>
      ) : (
        <span />
      )}
      <div className="flex flex-col gap-2 sm:flex-row">{children}</div>
    </div>
  );
}

export function NumberedList({ items }: { items: readonly ReactNode[] }) {
  return (
    <ol className="list-decimal pl-5 space-y-2 text-sm text-[var(--sg-text)]">
      {items.map((item, index) => (
        <li key={index}>{item}</li>
      ))}
    </ol>
  );
}

export function WhatHappens({
  provider,
  withRuns = false,
}: {
  provider: VcsProvider;
  withRuns?: boolean;
}) {
  return (
    <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-4 space-y-2">
      <div className="text-sm font-medium text-[var(--sg-text)]">{COPY.whatHappens.title}</div>
      <ul className="list-disc pl-5 space-y-1 text-sm text-[var(--sg-text-muted)]">
        <li>{COPY.whatHappens.planComment[provider]}</li>
        {provider === "github" ? <li>{COPY.whatHappens.approval}</li> : null}
        <li>{COPY.whatHappens.apply[provider]}</li>
        {withRuns ? <li>{COPY.whatHappens.runs}</li> : null}
      </ul>
    </div>
  );
}

export function ForkStep({
  provider,
  path,
  onBack,
  onConfirm,
}: {
  provider: VcsProvider;
  path?: {
    value: string;
    onChange: (value: string) => void;
    error: string | null;
  };
  onBack: () => void;
  onConfirm: () => void;
}) {
  const repository = DEMO_REPOSITORIES[provider];
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.fork.title[provider]} lead={COPY.fork.lead[provider]} />
      <div className="flex flex-wrap items-center gap-3">
        <Button asChild variant="outline">
          <a href={repository.forkUrl} target="_blank" rel="noopener noreferrer">
            <ExternalLink className="h-4 w-4" aria-hidden="true" />
            {COPY.fork.action[provider]}
          </a>
        </Button>
        <span className="text-xs text-[var(--sg-text-muted)]">{COPY.fork.opens[provider]}</span>
      </div>
      {path ? (
        <div className="space-y-2">
          <label htmlFor="orchestration-fork-path" className="text-sm font-medium text-[var(--sg-text)]">
            {COPY.fork.pathLabel}
          </label>
          <Input
            id="orchestration-fork-path"
            value={path.value}
            aria-invalid={path.error ? true : undefined}
            aria-describedby={path.error ? "orchestration-fork-path-error" : undefined}
            onChange={(event) => path.onChange(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") onConfirm();
            }}
          />
          {path.error ? (
            <div
              id="orchestration-fork-path-error"
              role="alert"
              className="rounded-md border border-[var(--sg-error)]/30 bg-[var(--sg-error)]/10 px-3 py-2 text-sm text-[var(--sg-error)]"
            >
              {path.error}
            </div>
          ) : null}
        </div>
      ) : null}
      <StepFooter onBack={onBack}>
        <Button onClick={onConfirm}>
          {COPY.fork.confirm} <ArrowRight className="h-4 w-4" />
        </Button>
      </StepFooter>
    </div>
  );
}

export function ActionsStep({ onBack, onConfirm }: { onBack: () => void; onConfirm: () => void }) {
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.actions.title} lead={COPY.actions.lead} />
      <NumberedList items={COPY.actions.steps} />
      <StepFooter onBack={onBack}>
        <Button onClick={onConfirm}>
          {COPY.actions.confirm} <ArrowRight className="h-4 w-4" />
        </Button>
      </StepFooter>
    </div>
  );
}

export function FirstChangeStep({
  provider,
  editUrl,
  onBack,
  onConfirm,
}: {
  provider: VcsProvider;
  editUrl?: string;
  onBack: () => void;
  onConfirm: () => void;
}) {
  const open =
    editUrl ? (
      <a
        href={editUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1"
      >
        {COPY.change.open[provider]} <ExternalLink className="h-3 w-3" />
      </a>
    ) : (
      COPY.change.open[provider]
    );
  const items: ReactNode[] = [
    open,
    <code key="edit" className="text-xs bg-[var(--sg-bg-2)] px-1.5 py-0.5 rounded">
      {COPY.change.editInstruction}
    </code>,
    ...(provider === "gitlab" ? [COPY.change.gitlabPush] : []),
    COPY.change.openRequest[provider],
  ];
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.change.title} lead={COPY.change.lead[provider]} />
      <NumberedList items={items} />
      <WhatHappens provider={provider} />
      <StepFooter onBack={onBack}>
        <Button onClick={onConfirm}>
          {COPY.change.confirm[provider]} <ArrowRight className="h-4 w-4" />
        </Button>
      </StepFooter>
    </div>
  );
}

export function WorkflowFileStep({
  provider,
  onBack,
  onContinue,
}: {
  provider: VcsProvider | null;
  onBack: () => void;
  onContinue: () => void;
}) {
  const known = provider ?? "github";
  return (
    <div className="space-y-6">
      <StepHeading
        title={COPY.runnable.title[known]}
        lead={provider ? COPY.runnable.lead[provider] : COPY.runnable.missingProvider}
      />
      {provider ? (
        <>
          <div className="space-y-2">
            <div className="text-sm text-[var(--sg-text-muted)]">
              {COPY.runnable.pathLabel}:{" "}
              <code className="text-[var(--sg-text)]">
                {provider === "github" ? GITHUB_WORKFLOW_PATH : GITLAB_PIPELINE_PATH}
              </code>
            </div>
            <CodeBlock
              code={provider === "github" ? GITHUB_WORKFLOW_YAML : GITLAB_PIPELINE_YAML}
              language={GITHUB_WORKFLOW_LANGUAGE}
            />
          </div>
          <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-4 space-y-2">
            <div className="text-sm font-medium text-[var(--sg-text)]">
              {COPY.runnable.whatHappensTitle}
            </div>
            <ul className="list-disc pl-5 space-y-1 text-sm text-[var(--sg-text-muted)]">
              <li>{COPY.runnable.roots}</li>
              <li>{COPY.runnable.plans}</li>
              <li>{COPY.runnable.applies}</li>
            </ul>
          </div>
        </>
      ) : null}
      <StepFooter onBack={onBack}>
        <Button onClick={onContinue} disabled={!provider}>
          {COPY.common.continue} <ArrowRight className="h-4 w-4" />
        </Button>
      </StepFooter>
    </div>
  );
}

export function CredentialsStep({
  provider,
  onBack,
  onDone,
  onSkip,
}: {
  provider: VcsProvider | null;
  onBack: () => void;
  onDone: () => void;
  onSkip: () => void;
}) {
  const body =
    provider === "github"
      ? COPY.credentials.githubBody
      : provider === "gitlab"
        ? COPY.credentials.gitlabBody
        : COPY.credentials.genericBody;
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.credentials.title} lead={COPY.credentials.requirement} />
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {CREDENTIAL_CARDS.map((card) => (
          <a
            key={card.id}
            href={card.href}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-4 hover:border-[var(--sg-accent)]"
          >
            <div className="flex items-center gap-2 text-sm font-medium text-[var(--sg-text)]">
              <Cloud className="h-4 w-4 text-[var(--sg-accent)]" />
              {card.label}
              <ExternalLink className="ml-auto h-3.5 w-3.5 text-[var(--sg-text-muted)]" />
            </div>
            <p className="mt-2 text-xs text-[var(--sg-text-muted)]">{body}</p>
          </a>
        ))}
      </div>
      <StepFooter onBack={onBack}>
        <Button variant="outline" onClick={onSkip}>
          {COPY.credentials.skip}
        </Button>
        <Button onClick={onDone}>
          <Check className="h-4 w-4" /> {COPY.credentials.done}
        </Button>
      </StepFooter>
    </div>
  );
}

export function PullRequestStep({
  provider,
  onBack,
  onConfirm,
}: {
  provider: VcsProvider;
  onBack: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.wait.title[provider]} lead={COPY.wait.lead[provider]} />
      <WhatHappens provider={provider} withRuns />
      <StepFooter onBack={onBack}>
        <Button onClick={onConfirm}>
          {COPY.wait.confirm[provider]} <ArrowRight className="h-4 w-4" />
        </Button>
      </StepFooter>
    </div>
  );
}

export function DoneStep({
  provider,
  summary,
  onSetUpState,
  onSwitchEngine,
  onConsole,
  onManageUsers,
}: {
  provider: VcsProvider;
  summary?: ReactNode;
  onSetUpState: () => void;
  onSwitchEngine: () => void;
  onConsole: () => void;
  onManageUsers: () => void;
}) {
  const { states, isLoading } = useStates();
  const progress = useSetupProgress();
  const offerState = !isLoading && states.length === 0;
  const offerEngine = !isLoading && states.length > 0 && !progress.isLoading && progress.engineRun !== true;
  return (
    <div className="space-y-6">
      <div className="inline-flex items-center gap-1.5 rounded-full bg-[var(--sg-success)]/10 px-3 py-1 text-xs font-medium text-[var(--sg-success)]">
        <Check className="h-3.5 w-3.5" /> {COPY.done.pill}
      </div>
      <StepHeading title={COPY.done.title[provider]} lead={COPY.done.lead[provider]} />
      {summary}
      {offerState ? (
        <Card className="gap-3 border-2">
          <CardHeader>
            <span className="text-[10px] uppercase tracking-wide font-medium text-[var(--sg-text-muted)]">
              {COPY.done.nextEyebrow}
            </span>
            <CardTitle>{COPY.done.iaadTitle}</CardTitle>
            <CardDescription>{COPY.done.iaadBody[provider]}</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-2">
            <Button onClick={onSetUpState}>
              {COPY.done.iaadAction} <ArrowRight className="h-4 w-4" />
            </Button>
            <Button variant="outline" onClick={onConsole}>
              {COPY.done.console}
            </Button>
          </CardContent>
        </Card>
      ) : offerEngine ? (
        <Card className="gap-3 border-2">
          <CardHeader>
            <span className="text-[10px] uppercase tracking-wide font-medium text-[var(--sg-text-muted)]">
              {COPY.done.nextEyebrow}
            </span>
            <CardTitle>{SETUP_COPY.engine.title}</CardTitle>
            <CardDescription>{SETUP_COPY.engine.nextBody}</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-2">
            <Button onClick={onSwitchEngine}>
              {SETUP_COPY.engine.action} <ArrowRight className="h-4 w-4" />
            </Button>
            <Button variant="outline" onClick={onConsole}>
              {COPY.done.console}
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div>
          <Button onClick={onConsole}>
            {COPY.done.console} <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      )}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="h-full gap-3">
          <CardHeader>
            <Settings className="h-5 w-5 text-[var(--sg-accent)]" />
            <CardTitle>{COPY.done.tuneTitle}</CardTitle>
            <CardDescription>{COPY.done.tuneDescription}</CardDescription>
          </CardHeader>
        </Card>
        <Card className="h-full gap-3">
          <CardHeader>
            <Users className="h-5 w-5 text-[var(--sg-accent)]" />
            <CardTitle>{COPY.done.usersTitle}</CardTitle>
            <CardDescription>{COPY.done.usersDescription}</CardDescription>
          </CardHeader>
          <CardContent className="mt-auto">
            <Button variant="outline" onClick={onManageUsers}>
              {COPY.done.usersAction}
            </Button>
          </CardContent>
        </Card>
        <Card className="h-full gap-3">
          <CardHeader>
            <ExternalLink className="h-5 w-5 text-[var(--sg-accent)]" />
            <CardTitle>{COPY.done.referenceTitle}</CardTitle>
            <CardDescription>{COPY.done.referenceDescription}</CardDescription>
          </CardHeader>
          <CardContent className="mt-auto">
            <Button asChild variant="outline">
              <a href={DOC_LINKS.configuration} target="_blank" rel="noopener noreferrer">
                {COPY.done.referenceAction}
              </a>
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
