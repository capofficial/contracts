exports.ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
exports.BPS_DIVIDER = 10000;

exports.toUnits = function(amount, units) {
  return ethers.utils.parseUnits(""+amount, units || 18);
}