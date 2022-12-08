const hre = require("hardhat");
const { ethers } = require('hardhat');
const { MARKETS, chainlinkFeeds } = require('./lib/markets.js');
const { ADDRESS_ZERO } = require('./lib/utils.js');

async function main() {

  const network = hre.network.name;
  console.log('Network', network);

  const provider = ethers.provider;

  const [signer, _oracle] = await ethers.getSigners();

  // Account
  const account = await signer.getAddress();
  console.log('Account', account);

  const marketStore = await (await ethers.getContractFactory("MarketStore")).attach("0xb75386a3F75930207f7E7C649Ce93c994f3dee40");


  const marketsToAdd = {
    'LINK-USD': {
      name: 'Chainlink / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0x86e53cf1b870786351da77a57575e79cb55812cb',
      fee: 30,
      liqThreshold: 9000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'YFI-USD': {
      name: 'Yearn Finance / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0x745ab5b69e01e2be1104ca84937bb71f96f5fb21',
      fee: 50,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'AAVE-USD': {
      name: 'Aave / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xad1d5344aade45f43e596773bcc4c423eabdd034',
      fee: 40,
      liqThreshold: 8500,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'SUSHI-USD': {
      name: 'Sushi / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xb2a8ba74cbca38508ba1632761b56c897060147c',
      fee: 50,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'UNI-USD': {
      name: 'Uniswap / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xb2a8ba74cbca38508ba1632761b56c897060147c',
      fee: 50,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'ADA-USD': {
      name: 'Cardano / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xd9f615a9b820225edba2d821c4a696a0924051c6',
      fee: 65,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'BNB-USD': {
      name: 'Binance / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 10,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0x6970460aabf80c5be983c6b74e5d06dedca95d4a',
      fee: 20,
      liqThreshold: 9000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'COMP-USD': {
      name: 'Compound / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xe7c53ffd03eb6cef7d208bc4c13446c76d1e5884',
      fee: 40,
      liqThreshold: 9000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'CRV-USD': {
      name: 'Curve / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xaebda2c976cfd1ee1977eac079b4382acb849325',
      fee: 65,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'MATIC-USD': {
      name: 'Polygon / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0x52099d4523531f678dfc568a7b1e5038aadce1d6',
      fee: 75,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'NEAR-USD': {
      name: 'Near / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xbf5c3fb2633e924598a46b9d07a174a9dbcf57c0',
      fee: 100,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'SOL-USD': {
      name: 'Solana / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0x24cea4b8ce57cda5058b924b9b9987992450590c',
      fee: 30,
      liqThreshold: 9000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'XRP-USD': {
      name: 'Ripple / U.S. Dollar',
      category: 'crypto',
      maxLeverage: 5,
      maxDeviation: 10000, // TEST on local only
      chainlinkFeed: '0xb4ad57b52ab9141de9926a3e0c8dc6264c2ef205',
      fee: 30,
      liqThreshold: 8000,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'AUD-USD': {
      name: 'Australian Dollar / U.S. Dollar',
      category: 'fx',
      maxLeverage: 100,
      maxDeviation: 10000, // TEST on local only
      fee: 5,
      chainlinkFeed: '0x9854e9a850e7c354c1de177ea953a6b1fba8fc22',
      liqThreshold: 9900,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'USD-CNY': {
      name: 'U.S. Dollar / Chinese Yuan',
      category: 'fx',
      maxLeverage: 50,
      maxDeviation: 10000, // TEST on local only
      fee: 5,
      chainlinkFeed: ADDRESS_ZERO,
      liqThreshold: 9900,
      allowChainlinkExecution: false,
      isClosed: false,
      isReduceOnly: false
    },
    'CAD-USD': {
      name: 'Canadian Dollar / U.S. Dollar',
      category: 'fx',
      maxLeverage: 100,
      maxDeviation: 10000, // TEST on local only
      fee: 3,
      chainlinkFeed: '0xf6da27749484843c4f02f5ad1378cee723dd61d4',
      liqThreshold: 9900,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'GBP-USD': {
      name: 'British Pound / U.S. Dollar',
      category: 'fx',
      maxLeverage: 100,
      maxDeviation: 10000, // TEST on local only
      fee: 3,
      chainlinkFeed: '0x9c4424fd84c6661f97d8d6b3fc3c1aac2bedd137',
      liqThreshold: 9900,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
    'USD-JPY': {
      name: 'U.S. Dollar / Japanese Yen',
      category: 'fx',
      maxLeverage: 100,
      maxDeviation: 10000, // TEST on local only
      fee: 3,
      chainlinkFeed: ADDRESS_ZERO,
      liqThreshold: 9900,
      allowChainlinkExecution: false,
      isClosed: false,
      isReduceOnly: false
    },
    'USD-KRW': {
      name: 'U.S. Dollar / South Korean Won',
      category: 'fx',
      maxLeverage: 50,
      maxDeviation: 10000, // TEST on local only
      fee: 5,
      chainlinkFeed: ADDRESS_ZERO,
      liqThreshold: 9900,
      allowChainlinkExecution: false,
      isClosed: false,
      isReduceOnly: false
    },
    'XAG-USD': {
      name: 'Silver / U.S. Dollar',
      category: 'commodities',
      maxLeverage: 10,
      maxDeviation: 10000, // TEST on local only
      fee: 25,
      chainlinkFeed: '0xc56765f04b248394cf1619d20db8082edbfa75b1',
      liqThreshold: 9500,
      allowChainlinkExecution: true,
      isClosed: false,
      isReduceOnly: false
    },
  };

  for (const id in marketsToAdd) {
    const _market = marketsToAdd[id];
    await marketStore.set(id, _market);
    console.log('Added ', id);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});