const express = require("express");
const { MongoClient } = require("mongodb");

const app = express();

const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;
const APP_VERSION = process.env.APP_VERSION || "1.0.0";

if (!MONGO_URI) {
  console.error("MONGO_URI is not configured");
  process.exit(1);
}

const client = new MongoClient(MONGO_URI);

let mongoReady = false;

async function connectMongo() {
  try {
    await client.connect();

    await client
      .db("studynow")
      .command({ ping: 1 });

    mongoReady = true;

    console.log("MongoDB connection successful");
  } catch (error) {
    mongoReady = false;
    console.error("MongoDB connection failed:", error.message);
    process.exit(1);
  }
}

app.get("/", (req, res) => {
  res.json({
    application: "StudyNow",
    status: "running",
    version: APP_VERSION
  });
});

app.get("/health", async (req, res) => {
  if (process.env.FORCE_UNHEALTHY === "true") {
    return res.status(503).json({
      status: "unhealthy",
      reason: "forced test failure"
    });
  }

  if (!mongoReady) {
    return res.status(503).json({
      status: "unhealthy",
      mongodb: "not ready"
    });
  }

  try {
    await client
      .db("studynow")
      .command({ ping: 1 });

    res.status(200).json({
      status: "healthy",
      mongodb: "healthy",
      version: APP_VERSION
    });
  } catch (error) {
    res.status(503).json({
      status: "unhealthy",
      mongodb: "unhealthy"
    });
  }
});

app.get("/api/time", (req, res) => {
  res.json({
    serverTime: new Date().toISOString()
  });
});

connectMongo().then(() => {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`StudyNow application running on port ${PORT}`);
  });
});