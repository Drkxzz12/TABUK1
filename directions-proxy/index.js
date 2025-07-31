const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Replace with your actual Google Directions API key
const GOOGLE_API_KEY = 'AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE';

app.use(cors());

app.get('/directions', async (req, res) => {
  const { origin, destination, mode = 'driving' } = req.query;
  if (!origin || !destination) {
    return res.status(400).json({ error: 'origin and destination are required' });
  }
  const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${GOOGLE_API_KEY}&mode=${mode}`;
  try {
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch directions', details: err.toString() });
  }
});

app.listen(PORT, () => {
  console.log(`Directions proxy server running on http://localhost:${PORT}`);
}); 