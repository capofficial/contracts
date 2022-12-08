const { time, loadFixture, takeSnapshot } = require("@nomicfoundation/hardhat-network-helpers");
// https://hardhat.org/hardhat-network-helpers/docs/reference

const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
// https://hardhat.org/hardhat-chai-matchers/docs/reference

const { expect } = require("chai");

const { ADDRESS_ZERO, BPS_DIVIDER, formatEvent, logReceipt, PRODUCTS, toUnits } = require('./utils.js');
const { setup } = require('./setup.js');

let loggingEnabled = true;
let snapshot;

let _ = {}; // stores setup variables

// Used because _ is not ready when ordersToSubmit needs to be filled (script start), so fills retroactively
function fillAsset(val) {
  if (val == 'usdc') return _.usdc.address;
  return val;
}

// all valid orders
let ordersToSubmit = [
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO,
    isLong: true, // long
    price: 0, // market order
    margin: toUnits(1),
    size: toUnits(5),
    orderType: 0,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(1).add(toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO,
    isLong: false, // short
    price: 0, // market order
    margin: toUnits(0.5),
    size: toUnits(10),
    orderType: 0,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(10).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(0.5).add(toUnits(10).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO,
    isLong: true, // long
    price: toUnits(1450), // limit order
    margin: toUnits(1),
    size: toUnits(5),
    orderType: 1,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(1).add(toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO, // ETH
    isLong: false, // short
    price: toUnits(1590), // limit order
    margin: toUnits(5),
    size: toUnits(5),
    orderType: 1,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(5).add(toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO, // ETH
    isLong: true, // long
    price: toUnits(1610),
    margin: toUnits(2),
    size: toUnits(5),
    orderType: 2,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(2).add(toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO, // ETH
    isLong: false, // short
    price: toUnits(1344), // stop order
    margin: toUnits(3),
    size: toUnits(10),
    orderType: 2,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(10).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(3).add(toUnits(10).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  },
  {
    market: 'ETH-USD',
    asset: 'usdc', // USDC
    isLong: true, // long
    price: 0, // market order
    margin: toUnits(1000, 6),
    size: toUnits(5000, 6),
    orderType: 0,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5000, 6).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)
  },
  {
    market: 'ETH-USD',
    asset: 'usdc', // USDC
    isLong: false, // short
    price: toUnits(1622), // limit order
    margin: toUnits(1000, 6),
    size: toUnits(5000, 6),
    orderType: 1,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5000, 6).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO, // ETH
    isLong: false, // short
    price: 0, // market order
    margin: toUnits(2),
    size: toUnits(5),
    orderType: 0,
    isReduceOnly: true,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER) // fee only
  },
  {
    market: 'ETH-USD',
    asset: ADDRESS_ZERO, // ETH
    isLong: true, // long
    price: toUnits(1610), // stop order
    margin: toUnits(2),
    size: toUnits(5),
    orderType: 2,
    isReduceOnly: true,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(2).add(toUnits(5).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)) // margin + fee, sent extra, expect refund
  },
  {
    market: 'ETH-USD',
    asset: 'usdc', // USDC
    isLong: false, // short
    price: toUnits(1544), // limit order
    margin: 0,
    size: toUnits(5000, 6),
    orderType: 1,
    isReduceOnly: true,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5000, 6).mul(PRODUCTS['ETH-USD'].fee).div(BPS_DIVIDER)
  },
  {
    market: 'BTC-USD', // new market 
    asset: ADDRESS_ZERO,
    isLong: true, // long
    price: 0, // market order
    margin: toUnits(1),
    size: toUnits(5),
    orderType: 0,
    isReduceOnly: false,
    expiry: 0,
    cancelOrderId: 0,
    feeAmount: toUnits(5).mul(PRODUCTS['BTC-USD'].fee).div(BPS_DIVIDER),
    value: toUnits(1).add(toUnits(5).mul(PRODUCTS['BTC-USD'].fee).div(BPS_DIVIDER)) // margin + fee
  }
];

// Tests

describe("Trading", function() {

  before(async function() {
    if (_.provider) return;
    console.log('Initializing...');
    _ = await setup();
    
    // console.log('Setting mock chainlink price...');

    // await _.chainlink.setMarketPrice(ADDRESS_ZERO, toUnits(1222));

    console.log('Setup done...');

    // console.log('Mock chainlink price', await _.chainlink.getPrice(ADDRESS_ZERO));

  });

  describe("submitOrder", function () {
    it("Should not submit below min size", async function() {

    });
  });

  /*describe("submitOrder", function () {

    let lastOpenInterestETH = ethers.BigNumber.from(0);
    let lastOpenInterestUSDC = ethers.BigNumber.from(0);

    describe("Should do error validations", async function() {

      it("Should not submit below min size", async function() {

      });
      it("Should not submit unsupported asset", async function() {

      });
      it("Should not submit unsupported market", async function() {

      });
      it("Should not submit below leverage = 1", async function() {

      });
      it("Should not submit above max leverage", async function() {

      });
      it("Should not submit if value is under required", async function() {

      });
      it("Should not submit limit buy order above price", async function() {

      });
      it("Should not submit limit sell order below price", async function() {

      });
      it("Should not submit stop buy order below price", async function() {

      });
      it("Should not submit stop sell order above price", async function() {

      });
      it("Should not submit tp below sl", async function() {

      });
      it("Should not submit limit order within minTriggerDistance", async function() {

      });
      it("Should not submit stop order within minTriggerDistance", async function() {

      });
      it("Should not submit order beyond maxOpenInterest", async function() {

      });
      it("Should not submit order if new positions are paused", async function() {

      });
      it("Should not transfer margin if isReduceOnly, only fee", async function() {

      });
      it("Should not submit limit/stop beyond max/min prices", async function() {

      });
      it("Should not submit order if trading is paused", async function() {

          // snapshot = await takeSnapshot();

          // expect(await _.pricefeed.getAssetPrice(ADDRESS_ZERO)).to.equal(toUnits(1499));
          // expect(await _.pricefeed.getMarketPrice('ETH-USD')).to.equal(toUnits(1498));

      });

    });
    
    ordersToSubmit.forEach((o, i) => {

      describe(`Should submit a new order on ${o.market} (order index=${i})`, async function() {

        let tx;

        const orderId = i + 1;

        it('Should submit successfully', async function () {

          // if (i == 9) console.log('Balance pre', await _.provider.getBalance(_.user1.address));

          tx = await _.orderbook.connect(_.user1).submitOrder(
            o.market,
            fillAsset(o.asset),
            o.isLong,
            o.margin,
            o.size,
            o.price,
            o.orderType,
            o.isReduceOnly,
            o.expiry,
            o.cancelOrderId,
            {value: o.value || 0} // margin + fee
          );

          receipt = await tx.wait();

          if (loggingEnabled) {
            logReceipt(receipt);
          }

          // if (i == 9) console.log('Balance post', await _.provider.getBalance(_.user1.address));

          await expect(receipt.status).to.equal(1);

        });

        it('Should emit a NewOrder event', async function () {

          await expect(tx).to.emit(_.orderbook, "NewOrder").withArgs(
            orderId,
            _.user1.address,
            o.market,
            fillAsset(o.asset),
            o.isLong,
            o.isReduceOnly ? 0 : o.margin,
            o.size,
            o.price,
            o.feeAmount,
            o.orderType,
            o.isReduceOnly,
            o.expiry,
            o.cancelOrderId
          );

        });

        it('Should expect balance change', async function () {

          let balanceSent = o.isReduceOnly ? o.feeAmount : o.margin.add(o.feeAmount);
          if (o.asset == ADDRESS_ZERO) {
            await expect(tx).to.changeEtherBalance(_.user1, balanceSent.mul(-1));
          } else if (o.asset == 'usdc') {
            await expect(tx).to.changeTokenBalance(_.usdc, _.user1, balanceSent.mul(-1));
          }

        });

        it('Should create new order object', async function () {

          const order = await _.orderbook.getOrder(orderId);

          expect(order.market).to.equal(o.market);
          expect(order.size).to.equal(o.size);
          expect(order.timestamp).to.be.gt(0);

        });

        it('Should update open interest', async function () {

          const oiETH = await _.trading.getOpenInterest(ADDRESS_ZERO);
          const oiUSDC = await _.trading.getOpenInterest(_.usdc.address);

          console.log('oiETH', oiETH);
          console.log('oiUSDC', oiUSDC);

          if (o.isReduceOnly) {
            expect(oiETH).to.equal(lastOpenInterestETH);
            expect(oiUSDC).to.equal(lastOpenInterestUSDC);
          } else {
            if (o.asset == ADDRESS_ZERO) {
              lastOpenInterestETH = lastOpenInterestETH.add(o.size);
              expect(oiETH).to.equal(lastOpenInterestETH);
            } else if (o.asset == 'usdc') {
              lastOpenInterestUSDC = lastOpenInterestUSDC.add(o.size);
              expect(oiUSDC).to.equal(lastOpenInterestUSDC);
            }
          }

        });

      });      

    });

  });*/

});