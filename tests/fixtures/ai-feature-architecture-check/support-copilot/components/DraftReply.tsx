// Test fixture.
export function DraftReply({ draft }: { draft: string }) {
  return (
    <section aria-label="AI-generated draft">
      <p className="badge">AI-generated draft. Check it before you send it.</p>
      <div data-ai-generated="true">{draft}</div>
    </section>
  );
}
