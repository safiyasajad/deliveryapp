require('dotenv').config();

const bcrypt = require('bcryptjs');
const db = require('../src/db');

const testUser = {
  email: 'user@example.com',
  password: 'Password123',
  firstName: 'John',
  lastName: 'Doe',
  role: 'ADMIN',
};

async function seed() {
  const passwordHash = await bcrypt.hash(testUser.password, 12);

  const companyResult = await db.query(
    `
      INSERT INTO companies (name, is_active, is_verified)
      VALUES ($1, TRUE, TRUE)
      ON CONFLICT (name)
      DO UPDATE SET
        is_active = TRUE,
        is_verified = TRUE,
        updated_at = NOW()
      RETURNING id
    `,
    ['OrderX QA Company'],
  );

  const companyId = companyResult.rows[0].id;

  await db.query(
    `
      INSERT INTO users (
        company_id,
        email,
        password_hash,
        first_name,
        last_name,
        role,
        is_active,
        is_verified
      )
      VALUES ($1, $2, $3, $4, $5, $6, TRUE, TRUE)
      ON CONFLICT (email)
      DO UPDATE SET
        company_id = EXCLUDED.company_id,
        password_hash = EXCLUDED.password_hash,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        role = EXCLUDED.role,
        is_active = TRUE,
        is_verified = TRUE,
        updated_at = NOW()
    `,
    [
      companyId,
      testUser.email,
      passwordHash,
      testUser.firstName,
      testUser.lastName,
      testUser.role,
    ],
  );

  console.log('Seed data created');
  console.log(`Email: ${testUser.email}`);
  console.log(`Password: ${testUser.password}`);
}

seed()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await db.pool.end();
  });
