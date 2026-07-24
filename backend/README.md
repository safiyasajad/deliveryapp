# Delivery App Backend

Node.js + Express backend for the OrderX delivery app login API.

## Requirements

- Node.js 18+
- PostgreSQL 13+

## Setup

1. Install dependencies:

   ```powershell
   npm install
   ```

2. Create a local environment file:

   ```powershell
   copy .env.example .env
   ```

3. Update `.env` with your PostgreSQL connection string and JWT secrets.

4. Create the database if it does not already exist:

   ```powershell
   createdb deliveryapp
   ```

5. Apply the schema. PowerShell does not automatically load `.env`, so set the
   database URL for this terminal first:

   ```powershell
   $env:DATABASE_URL="postgres://postgres:postgres@localhost:5432/deliveryapp"
   psql "$env:DATABASE_URL" -f schema.sql
   ```

6. Seed a test company and user:

   ```powershell
   npm run seed
   ```

   Test credentials:

   ```text
   Email: user@example.com
   Password: Password123
   ```

7. Start the API:

   ```powershell
   npm run dev
   ```

## Endpoints

### `GET /health`

Returns:

```json
{
  "status": "ok"
}
```

### `POST /login`

Authenticates an active, verified user whose company is also active and verified.

Request:

```json
{
  "email": "user@example.com",
  "password": "Password123"
}
```

PowerShell test:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:3000/login" `
  -ContentType "application/json" `
  -Body '{"email":"user@example.com","password":"Password123"}'
```

Success response:

```json
{
  "message": "Successful login",
  "accessToken": "<JWT Access Token>",
  "refreshToken": "<JWT Refresh Token>",
  "roles": ["ADMIN"],
  "dashboardUrl": "/user/dashboard-admin",
  "user": {
    "id": "user-id",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }
}
```
