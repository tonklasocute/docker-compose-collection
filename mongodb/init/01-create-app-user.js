// Runs once, on the first start with an empty data volume, as the root user.
// Creates a least-privilege application user (APP_DB_* in .env) and a sample
// collection, so apps don't connect as root.
const dbName = process.env.APP_DB_NAME;
const app = db.getSiblingDB(dbName);

app.createUser({
  user: process.env.APP_DB_USER,
  pwd: process.env.APP_DB_PASSWORD,
  roles: [{ role: "readWrite", db: dbName }],
});

app.notes.insertOne({ body: "hello from init/01-create-app-user.js", createdAt: new Date() });
