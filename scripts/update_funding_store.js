const hre = require("hardhat");
const { ethers } = require('hardhat');
const { MARKETS, chainlinkFeeds } = require('./lib/markets.js');

async function main() {

  const network = hre.network.name;
  console.log('Network', network);

  const provider = ethers.provider;

  const [signer, _oracle] = await ethers.getSigners();

  // Account
  const account = await signer.getAddress();
  console.log('Account', account);

  const roleStoreAddress = "0xE1040f058De8C8835cEEBF9d6D1d8c449d989366";
  const dataStoreAddress = "0x360B0B2b3391FD65D8279E2231C80D9De767ad7b";

  // Funding Store
  const FundingStore = await ethers.getContractFactory("FundingStore");
  const fundingStore = await FundingStore.deploy(roleStoreAddress);
  await fundingStore.deployed();
  console.log(`FundingStore deployed to ${fundingStore.address}.`);

  const dataStore = await (await ethers.getContractFactory("DataStore")).attach(dataStoreAddress);
  await dataStore.setAddress("FundingStore", fundingStore.address, true);
  console.log('DataStore configured.');

  const funding = await (await ethers.getContractFactory("Funding")).attach(await dataStore.getAddress("Funding"));
  const positions = await (await ethers.getContractFactory("Positions")).attach(await dataStore.getAddress("Positions"));

  await funding.link();
  await positions.link();
  console.log('Contracts linked.');


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});