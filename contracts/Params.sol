pragma solidity ^0.8.0;

import "./Entity.sol";

library Params {
	/**
	 * @dev Define swap item
	 */
	struct SwapItemParams {
		string id;
		address contractAddress;
		uint256 amount;
		uint256 tokenId;
		Entity.SwapItemType itemType;
	}

	/**
	 * @dev Define swap option
	 */
	struct SwapOptionParams {
		string id;
		SwapItemParams[] askingItems;
	}

	/**
	 * @dev Define proposal
	 */
	struct ProposalParams {
		string id;
		uint256 expiredAt;
		SwapItemParams[] offeredItems;
		SwapOptionParams[] swapOptions;
	}
}
