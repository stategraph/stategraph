import assert from "node:assert";
import {
  firstPlanQuery,
  gitlabBaseUrl,
  gitlabInstallationLinkQuery,
  gitlabInstallationStateQuery,
  gitlabResumeOutcome,
  gitlabWizardLinks,
  isValidGroupId,
} from "./mqlQueries";

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
  }
}

test("firstPlanQuery counts pull request plan runs by state on the provider's table", () => {
  assert.equal(
    firstPlanQuery("github"),
    "select state, count(*) as c from github_work_manifests where run_kind = 'pr' and run_type in ('plan', 'autoplan') group by state",
  );
  assert.match(firstPlanQuery("gitlab"), / from gitlab_work_manifests /);
});

test("state query targets gitlab_installations by id", () => {
  assert.equal(
    gitlabInstallationStateQuery("1043"),
    "select state as state from gitlab_installations where id = 1043",
  );
});

test("state query refuses anything but a valid group id", () => {
  assert.throws(() => gitlabInstallationStateQuery("1; drop"));
  assert.throws(() => gitlabInstallationStateQuery(""));
  assert.equal(
    gitlabInstallationStateQuery(" 1043 "),
    "select state as state from gitlab_installations where id = 1043",
  );
});

test("isValidGroupId accepts a bounded positive integer only", () => {
  assert.equal(isValidGroupId("1043"), true);
  assert.equal(isValidGroupId(" 1043 "), true);
  assert.equal(isValidGroupId(""), false);
  assert.equal(isValidGroupId("0"), false);
  assert.equal(isValidGroupId("000"), false);
  assert.equal(isValidGroupId("0x10"), false);
  assert.equal(isValidGroupId("12'; drop"), false);
  // over-long ids would lose precision through the JSON/int round trip
  assert.equal(isValidGroupId("1234567890123456"), false);
});

test("gitlabBaseUrl accepts only http(s) and drops what would break a link", () => {
  assert.equal(gitlabBaseUrl("javascript:alert(1)"), null);
  assert.equal(gitlabBaseUrl("ftp://x"), null);
  assert.equal(gitlabBaseUrl("gitlab.com"), null);
  assert.equal(gitlabBaseUrl(" https://gitlab.example.com/gitlab/ "), "https://gitlab.example.com/gitlab");
  assert.equal(gitlabBaseUrl("https://gitlab.com?x#y"), "https://gitlab.com");
});

test("gitlabWizardLinks builds encoded project links", () => {
  const l = gitlabWizardLinks("https://gitlab.example.com", "grp/sub", "my repo");
  assert.equal(l.hooksUrl, "https://gitlab.example.com/grp/sub/my%20repo/-/hooks");
  assert.equal(l.cicdUrl, "https://gitlab.example.com/grp/sub/my%20repo/-/settings/ci_cd");
  assert.equal(l.repoUrl, "https://gitlab.example.com/grp/sub/my%20repo");
  assert.equal(l.groupTokensUrl, "https://gitlab.example.com/groups/grp/sub/-/settings/access_tokens");
  assert.equal(l.projectTokensUrl, "https://gitlab.example.com/grp/sub/my%20repo/-/settings/access_tokens");
  assert.equal(l.personalTokensUrl, "https://gitlab.example.com/-/user_settings/personal_access_tokens");
});

test("gitlabWizardLinks yields empty strings without a project", () => {
  const l = gitlabWizardLinks("https://gitlab.com", "grp", "");
  assert.equal(l.hooksUrl, "");
  assert.equal(l.repoUrl, "");
  assert.notEqual(l.groupTokensUrl, "");
});

test("gitlabInstallationLinkQuery reads the group's map rows with state, for a valid id only", () => {
  assert.equal(
    gitlabInstallationLinkQuery(" 1043 "),
    "select gim.core_id as core_id, gi.state as state from gitlab_installations_map as gim inner join gitlab_installations as gi on gi.id = gim.installation_id where gim.installation_id = 1043",
  );
  assert.throws(() => gitlabInstallationLinkQuery("1; drop"));
  assert.throws(() => gitlabInstallationLinkQuery(""));
});

test("gitlabResumeOutcome only resumes an installed group linked to this tenant", () => {
  assert.equal(gitlabResumeOutcome(["a"], []), "not-linked");
  // Visible through MQL (another tenant of the same user) but not this tenant's.
  assert.equal(gitlabResumeOutcome(["a"], [{ core_id: "b", state: "installed" }]), "not-linked");
  assert.equal(gitlabResumeOutcome(["a"], [{ core_id: "a", state: "installed" }]), "installed");
  assert.equal(gitlabResumeOutcome(["a"], [{ core_id: "a", state: "pending" }]), "pending");
});

process.exit(failures === 0 ? 0 : 1);
