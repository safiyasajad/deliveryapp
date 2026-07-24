function notFoundMiddleware(req, res) {
  res.status(404).json({
    message: `Route ${req.method} ${req.originalUrl} not found`,
  });
}

function errorMiddleware(err, _req, res, _next) {
  const statusCode = err.statusCode || 500;

  res.status(statusCode).json({
    message: err.message || 'Internal server error',
  });
}

module.exports = {
  errorMiddleware,
  notFoundMiddleware,
};
