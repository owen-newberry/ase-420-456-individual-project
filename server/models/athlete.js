const mongoose = require('mongoose');

const AthleteSchema = new mongoose.Schema({
  name: { type: String, required: true },
  age: Number,
  email: String
});

module.exports = mongoose.model('Athlete', AthleteSchema);
