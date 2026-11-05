"use client";

import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { Mail, ExternalLink, BookOpen } from "lucide-react";
import { GithubIcon, SlackIcon } from "@/components/ui/brand-icons";

const channels = [
  {
    title: "GitHub Issues",
    description:
      "Report bugs and request features. Issues are public and searchable, so others can find the answer.",
    href: "https://github.com/stategraph/stategraph/issues",
    cta: "Open Issues",
    icon: <GithubIcon className="h-6 w-6" />,
    best_for: "Bug reports, feature requests, and troubleshooting",
  },
  {
    title: "Email Support",
    description:
      "Reach out directly for account issues, security concerns, or anything that requires a private conversation.",
    href: "mailto:support@stategraph.com",
    cta: "support@stategraph.com",
    icon: <Mail className="h-6 w-6" />,
    best_for: "Account issues, security concerns, private or sensitive inquiries",
  },
  {
    title: "Slack",
    description:
      "Join the community to discuss infrastructure systems, architecture decisions, and tradeoffs. A place for technical conversation, not a support channel.",
    href: "https://stategraph.com/slack",
    cta: "Join Slack",
    icon: <SlackIcon className="h-6 w-6" />,
    best_for: "Technical discussion, architecture tradeoffs, community conversation",
  },
  {
    title: "Documentation",
    description:
      "Browse guides, API references, and setup instructions to get the most out of Stategraph.",
    href: "https://stategraph.com/docs",
    cta: "Read the Docs",
    icon: <BookOpen className="h-6 w-6" />,
    best_for: "Setup guides, API reference, configuration, and how things work",
  },
];

export default function SupportPage() {
  return (
    <>
      <PageHeader
        title="Support"
        subtitle="Get help, report issues, or join the conversation"
      />
      <div className="p-6">
        <PageSection>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {channels.map((channel) => (
              <PageSurface key={channel.title}>
                <div className="flex flex-col h-full">
                  <div className="flex items-start gap-4 mb-3">
                    <div className="p-2 rounded-lg bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] flex-shrink-0">
                      {channel.icon}
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-base font-medium text-[var(--sg-text)]">
                        {channel.title}
                      </h3>
                      <p className="text-sm text-[var(--sg-text-muted)] mt-1">
                        {channel.description}
                      </p>
                    </div>
                  </div>
                  <div className="text-xs text-[var(--sg-text-dim)] mb-4">
                    <span className="font-medium text-[var(--sg-text-muted)]">Best for:</span>{" "}
                    {channel.best_for}
                  </div>
                  <div className="mt-auto">
                    <a
                      href={channel.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-sm font-medium text-[var(--sg-accent)] hover:underline"
                    >
                      {channel.cta}
                      <ExternalLink className="h-3.5 w-3.5" />
                    </a>
                  </div>
                </div>
              </PageSurface>
            ))}
          </div>
        </PageSection>
      </div>
    </>
  );
}
