import { parseAbi } from "viem";

/** Events emitted by OrkoPay that the indexer consumes. Keep in sync with IOrkoPay.sol. */
export const orkoPayAbi = parseAbi([
  "event PaymentReceived(bytes32 indexed orderId, address indexed customer, address indexed merchant, address asset, uint256 gross, uint256 fee)",
  "event OrderRefunded(bytes32 indexed orderId, address indexed customer, address asset, uint256 amount)",
]);
