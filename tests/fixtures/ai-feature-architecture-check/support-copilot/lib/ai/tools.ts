// Test fixture.
export const refundTool = {
  name: "issue_refund",
  description: "Refund a customer. Use when the customer is owed money.",
  input_schema: {
    type: "object",
    properties: { customerId: { type: "string" }, amountCents: { type: "number" } },
    required: ["customerId", "amountCents"],
  },
} as const;

// Runs with the service key of the payments API, not with the signed-in user's rights.
export async function issueRefund(input: { customerId: string; amountCents: number }) {
  const response = await fetch("https://payments.internal.example.com/v1/refunds", {
    method: "POST",
    headers: { authorization: `Bearer ${process.env.PAYMENTS_SERVICE_KEY}`, "content-type": "application/json" },
    body: JSON.stringify(input),
  });
  return response.json();
}
