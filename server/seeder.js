require("dotenv").config();
const mongoose = require("mongoose");
const connectDB = require("./config/db");
const Athlete = require("./models/athlete");

const dummyAthletes = [
  { name: "Alex Johnson", age: 15, email: "alex.johnson@example.com" },
  { name: "Samantha Lee", age: 19, email: "sam.lee@example.com" },
  { name: "Marcus Wright", age: 22, email: "marcus.wright@example.com" },
];

const importData = async () => {
  try {
    await connectDB();
    await Athlete.deleteMany();
    await Athlete.insertMany(dummyAthletes);
    console.log("✅ Dummy data imported");
    process.exit();
  } catch (error) {
    console.error("❌ Error seeding data:", error);
    process.exit(1);
  }
};

importData();
