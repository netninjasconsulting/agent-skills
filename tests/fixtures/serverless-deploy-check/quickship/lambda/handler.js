const { Client } = require("pg");

exports.ingest = async (event) => {
  if ((event.body || "").length > 262144) {
    return { statusCode: 413, body: "too large" };
  }
  const db = new Client({ connectionString: process.env.DB_URL });
  await db.connect();
  await db.query("insert into shipments (code) values ($1)", [event.body]);
  await db.end();
  return { statusCode: 200, body: "ok" };
};
