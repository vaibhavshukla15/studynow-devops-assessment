const database = process.env.MONGO_APP_DB;
const username = process.env.MONGO_APP_USER;
const password = process.env.MONGO_APP_PASSWORD;

const targetDatabase = db.getSiblingDB(database);

targetDatabase.createUser({
  user: username,
  pwd: password,
  roles: [
    {
      role: "readWrite",
      db: database
    }
  ]
});

print(`Application user created for database: ${database}`);