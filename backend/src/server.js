require('dotenv').config();

const cors = require('cors');
const express = require('express');
const morgan = require('morgan');

const authRoutes = require('./routes/auth.routes');
const { errorMiddleware, notFoundMiddleware } = require('./middleware/error.middleware');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/', authRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

app.listen(port, () => {
  console.log(`Backend API running on http://localhost:${port}`);
});
