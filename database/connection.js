const { Pool } = require("pg");
const fs = require("fs");
const path = require("path");

/**
 * Database connection and initialization module
 * Handles PostgreSQL connection with AWS Secrets Manager integration
 */

let pool = null;

/**
 * Initialize database connection pool
 */
async function initializeDatabase() {
  try {
    // Database configuration from environment variables
    const dbConfig = {
      host: process.env.DB_HOST || "localhost",
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_NAME || "mailsystem",
      user: process.env.DB_USER || "mailuser",
      password: process.env.DB_PASSWORD || "password",
      ssl:
        process.env.NODE_ENV === "production"
          ? { rejectUnauthorized: false }
          : false,
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    };

    pool = new Pool(dbConfig);

    // Test connection
    const client = await pool.connect();
    console.log("✅ Database connected successfully");

    // Initialize schema
    await initializeSchema(client);

    client.release();

    return pool;
  } catch (error) {
    console.error("❌ Database connection failed:", error.message);

    // Fallback to in-memory storage for development
    if (process.env.NODE_ENV !== "production") {
      console.log("⚠️  Falling back to in-memory storage for development");
      // Reject the promise to signal database is unavailable
      throw new Error("Database connection failed - using in-memory storage");
    }

    throw error;
  }
}

/**
 * Initialize database schema
 */
async function initializeSchema(client) {
  try {
    const schemaPath = path.join(__dirname, "../database/init.sql");
    const schema = fs.readFileSync(schemaPath, "utf8");

    await client.query(schema);
    console.log("✅ Database schema initialized");
  } catch (error) {
    console.error("❌ Schema initialization failed:", error.message);
    throw error;
  }
}

/**
 * Get database connection pool
 */
function getPool() {
  return pool;
}

/**
 * Execute a database query
 */
async function query(text, params) {
  if (!pool) {
    throw new Error("Database not initialized");
  }

  const start = Date.now();
  const result = await pool.query(text, params);
  const duration = Date.now() - start;

  console.log("📊 Query executed", {
    text: text.substring(0, 50),
    duration,
    rows: result.rowCount,
  });
  return result;
}

/**
 * Close database connection
 */
async function closeDatabase() {
  if (pool) {
    await pool.end();
    console.log("✅ Database connection closed");
  }
}

module.exports = {
  initializeDatabase,
  getPool,
  query,
  closeDatabase,
};
