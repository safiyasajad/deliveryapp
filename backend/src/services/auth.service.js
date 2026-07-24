const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const db = require('../db');

function createHttpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function requireJwtConfig() {
  const accessSecret = process.env.JWT_ACCESS_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;

  if (!accessSecret || !refreshSecret) {
    throw createHttpError(500, 'JWT secrets are not configured');
  }

  return {
    accessSecret,
    refreshSecret,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  };
}

function createTokens(user) {
  const jwtConfig = requireJwtConfig();
  const payload = {
    sub: user.id,
    email: user.email,
    role: user.role,
    companyId: user.company_id,
  };

  return {
    accessToken: jwt.sign(payload, jwtConfig.accessSecret, {
      expiresIn: jwtConfig.accessExpiresIn,
    }),
    refreshToken: jwt.sign(payload, jwtConfig.refreshSecret, {
      expiresIn: jwtConfig.refreshExpiresIn,
    }),
  };
}

function getDashboardUrl(role) {
  return role === 'ADMIN' ? '/user/dashboard-admin' : '/user/dashboard';
}

function normalizeEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

function validateLoginBody(body) {
  const email = normalizeEmail(body.email);
  const password = body.password;

  if (!email || !password) {
    throw createHttpError(400, 'Email and password are required');
  }

  return { email, password };
}

async function findUserForLogin(email) {
  const result = await db.query(
    `
      SELECT
        users.id,
        users.company_id,
        users.email,
        users.password_hash,
        users.first_name,
        users.last_name,
        users.role,
        users.is_active AS user_is_active,
        users.is_verified AS user_is_verified,
        companies.is_active AS company_is_active,
        companies.is_verified AS company_is_verified
      FROM users
      INNER JOIN companies ON companies.id = users.company_id
      WHERE users.email = $1
      LIMIT 1
    `,
    [email],
  );

  return result.rows[0];
}

async function loginUser(body) {
  const { email, password } = validateLoginBody(body);
  const user = await findUserForLogin(email);

  if (!user) {
    throw createHttpError(401, 'Invalid email or password');
  }

  const passwordMatches = await bcrypt.compare(password, user.password_hash);

  if (!passwordMatches) {
    throw createHttpError(401, 'Invalid email or password');
  }

  if (!user.user_is_active || !user.user_is_verified) {
    throw createHttpError(403, 'User account is inactive or unverified');
  }

  if (!user.company_is_active || !user.company_is_verified) {
    throw createHttpError(403, 'Company account is inactive or unverified');
  }

  const tokens = createTokens(user);

  return {
    message: 'Successful login',
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    roles: [user.role],
    dashboardUrl: getDashboardUrl(user.role),
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
    },
  };
}

module.exports = {
  loginUser,
};
