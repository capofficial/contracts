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

  // Processor
  const Processor = await ethers.getContractFactory("Processor");
  const processor = await Processor.deploy("0xE1040f058De8C8835cEEBF9d6D1d8c449d989366", "0x360B0B2b3391FD65D8279E2231C80D9De767ad7b");
  await processor.deployed();
  console.log(`Processor deployed to ${processor.address}.`);

  await processor.link();
  console.log('Processor linked.');

  const roleStore = await (await ethers.getContractFactory("RoleStore")).attach("0xE1040f058De8C8835cEEBF9d6D1d8c449d989366");

  const CONTRACT_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("CONTRACT"));
  await roleStore.grantRole(processor.address, CONTRACT_ROLE);
  console.log('Role granted.');

  const dataStore = await (await ethers.getContractFactory("DataStore")).attach("0x360B0B2b3391FD65D8279E2231C80D9De767ad7b");
  await dataStore.setAddress("Processor", processor.address, true);
  console.log('DataStore configured.');

  // Fund pool store

  // // Create a transaction object
  // let tx = {
  //     to: "0x9cC87998ba85D81e017E6B7662aC00eE2Ab8fe13",
  //     // Convert asset unit from ether to wei
  //     value: ethers.utils.parseEther("100")
  // }
  // // Send a transaction
  // signer.sendTransaction(tx)
  // .then((txObj) => {
  //     console.log('txHash', txObj.hash)
  //     // => 0x9c172314a693b94853b49dc057cf1cb8e529f29ce0272f451eea8f5741aa9b58
  //     // A transaction result can be checked in a etherscan with a transaction hash which can be obtained here.
  // });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});