require('dotenv').config();
const express = require('express');
const connectDB = require('./config/db');
const mongoose = require('mongoose');
const cors = require('cors');

const athleteRoutes = require('./routes/athleteRoutes');

const app = express();
app.use(cors());
app.use(express.json());

connectDB();

app.use('/api/athletes', athleteRoutes);

app.listen(3000, () => console.log('Server running on port 3000'));
