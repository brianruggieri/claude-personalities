Create a React component called `StatusBadge` in a file called `StatusBadge.jsx`.

Requirements:
- Accepts a `status` prop: one of "active", "inactive", "pending"
- Accepts an optional `label` prop (string) — if not provided, use the status as the label
- Renders a `<span>` with:
  - A CSS class of `status-badge status-{status}` (e.g., `status-badge status-active`)
  - The label text inside the span
  - A `data-testid="status-badge"` attribute
- Export the component as the default export

Do not use any external libraries. Do not create any other files.
