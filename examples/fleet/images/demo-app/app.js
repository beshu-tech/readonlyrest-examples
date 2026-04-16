var apm = require('elastic-apm-node').start({
  serverUrl: 'https://apm-agent:8200',
  serviceName: 'demo-app',
  environment: 'ror-fleet-example',
  serverCaCertFile: '/certs/ca.crt',
  logLevel: 'info'
});

const express = require('express');
const app = express();

app.get('/', (req, res) => {
  const transaction = apm.startTransaction('MyCustomTransaction', 'custom');
  setTimeout(() => {
    transaction.end();
    res.send('Hello World!');
  }, 1000);
});

app.get('/error', (req, res) => {
  apm.captureError(new Error('Something went wrong!'));
  res.status(500).send('Internal Server Error');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
