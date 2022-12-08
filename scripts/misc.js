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

  // const fundingStore = await (await ethers.getContractFactory("FundingStore")).attach("0xB919CA11F87a5D192CBC8848dfdaFD91AF236F34");

  // console.log(await fundingStore.getFundingTracker('0x0000000000000000000000000000000000000000', 'ETH-USD'));
  // console.log(await fundingStore.getFundingTracker('0x0000000000000000000000000000000000000000', 'BTC-USD'));
  // console.log(await fundingStore.getFundingTracker('0x0000000000000000000000000000000000000000', 'EUR-USD'));
  // console.log(await fundingStore.getFundingTracker('0x0000000000000000000000000000000000000000', 'XAU-USD'));
    
  const positionStore = await (await ethers.getContractFactory("PositionStore")).attach("0xaeC9B38eA22cd4242235a2822bd0faCfb3b3bf13");

  console.log(await positionStore.getUserPositions('0x5765B3627F5D9faF79A6280b05dC9336e51f7A99'));
  // console.log(await positionStore.getPositions(['0x5765B3627F5D9faF79A6280b05dC9336e51f7A99'], ['0x0000000000000000000000000000000000000000'], ['ETH-USD']));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});