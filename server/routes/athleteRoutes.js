const express = require('express');
const router = express.Router();
const Athlete = require('../models/athlete');

router.get('/', async (req, res) => {
  const athletes = await Athlete.find();
  res.json(athletes);
});

router.post('/', async (req, res) => {
  const athlete = new Athlete(req.body);
  await athlete.save();
  res.status(201).json(athlete);
});

router.put('/:id', async (req, res) => {
  const athlete = await Athlete.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(athlete);
});

router.delete('/:id', async (req, res) => {
  await Athlete.findByIdAndDelete(req.params.id);
  res.json({ message: 'Deleted' });
});

module.exports = router;
