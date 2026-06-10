// =============================================================================
// KumaHost FiveM API — middleware/validate.js
// Request validation using zod schemas at the system boundary.
// =============================================================================

// validate(schema, source) — parse req[source] with a zod schema.
// On success the parsed value replaces the raw input; on failure → 400.
export function validate(schema, source = 'body') {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      return res.status(400).json({
        error: 'Validierungsfehler',
        details: result.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })),
      });
    }
    req[source] = result.data;
    return next();
  };
}
