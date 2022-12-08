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

  const assetStore = await (await ethers.getContractFactory("AssetStore")).attach("0xFF5CE0C5Cb81fBcB81f9B73Fcd34642AdC739228");

  await assetStore.set('0x0000000000000000000000000000000000000000', {minSize: ethers.utils.parseEther("0.00001"), chainlinkFeed: chainlinkFeeds['ETH']});
  await assetStore.set('0xff970a61a04b1ca14834a43f5de4533ebddb5cc8', {minSize: 10000, chainlinkFeed: chainlinkFeeds['USDC']});
  await assetStore.set('0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f', {minSize: ethers.utils.parseEther("0.00001"), chainlinkFeed: chainlinkFeeds['BTC']});
  console.log(`Assets configured.`);

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