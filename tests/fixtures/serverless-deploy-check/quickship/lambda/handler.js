const { Client } = require("pg");

exports.ingest = async (event) => {
  const db = new Client({ connectionString: process.env.DB_URL });
  await db.connect();
  await db.query("insert into shipments (code) values ($1)", [event.body]);
  await db.end();
  return { statusCode: 200, body: "ok" };
};
