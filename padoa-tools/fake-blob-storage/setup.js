const { BlobServiceClient, StorageSharedKeyCredential, BaseRequestPolicy, newPipeline } = require('@azure/storage-blob');
const https = require('https');

const containerNames = process.env.BLOB_CONTAINER_NAMES || 'filemedia-local';
const containers = containerNames.split(',');

const hostname = process.env.BLOB_CONNECT_ADDRESS || '127.0.0.1';
const port = process.env.BLOB_PORT || 10000;
const numberOfConnectionTries = 10;
const isHttps = process.env.IS_HTTPS || false;
const protocol = isHttps ? 'https' : 'http';

class CustomAgentPolicyFactory {
  agent;
  constructor(agent) {
    this.agent = agent;
  }

  create(nextPolicy, options) {
    return new CustomAgentPolicy(nextPolicy, { ...options, agent: this.agent });
  }
}

class CustomAgentPolicy extends BaseRequestPolicy {
  options;
  constructor(nextPolicy, options) {
    super(nextPolicy, options);
    this.options = options;
  }

  async sendRequest(request) {
    request.agent = this.options.agent;
    return this._nextPolicy.sendRequest(request);
  }
}

const customAgent = new https.Agent({ rejectUnauthorized: false });

// Azurite default credentials
const accountName = 'devstoreaccount1';
const sharedKeyCredential = 'Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==';

const tryConnection = async (client, remainingTries) => {
  try {
    await client.getProperties();
  } catch (e) {
    const remain = remainingTries - 1;
    if (remain === 0) {
      console.log('Impossible to connect to Fake Blob Storage even when retrying!');
      throw e;
    } else {
      console.log(`Failed to get Blob Storage properties, fake blob storage might not be available. Remaining tries : ${remain}. Error : ${e}`);
      await new Promise((res) => setTimeout(res, 1000));
      await tryConnection(client, remain);
    }
  }
};

const createContainers = async (containers, { hostname, port, accountName, sharedKeyCredential }) => {
  const url = `${protocol}://${hostname}:${port}/${accountName}`;
  console.log('aaaaa debug aaaaaaa', { url, accountName, sharedKeyCredential });
  const storageSharedKeyCredential = new StorageSharedKeyCredential(accountName, sharedKeyCredential);
  const customPipeline = newPipeline(storageSharedKeyCredential);
  customPipeline.factories.unshift(new CustomAgentPolicyFactory(customAgent));
  const client = isHttps ? new BlobServiceClient(url, customPipeline) : new BlobServiceClient(url, storageSharedKeyCredential);
  await tryConnection(client, numberOfConnectionTries);
  for (const container of containers) {
    try {
      console.log(`Creating container ${container}...`);
      await client.createContainer(container);
      console.log(`Container ${container} created.`);
    } catch (err) {
      // Container already exists
      if (err.statusCode === 409) {
        console.log(`Container ${container} already exists.`);
      } else {
        throw err;
      }
    }
  }
  console.log('All containers created !');
};

createContainers(containers, { hostname, port, accountName, sharedKeyCredential }).catch(console.log);
