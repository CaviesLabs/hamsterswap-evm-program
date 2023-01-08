pragma solidity ^0.8.0;

library Entity {
	/*
	 * @dev Define the item type
	 */
	enum SwapItemType {
		NFT,
		Currency
	}

	/**
	 * @dev Define status enum
	 */
	enum SwapItemStatus {
		Created,
		Deposited,
		Redeemed,
		Withdrawn
	}

	/**
	 * @dev Define proposal status
	 */
	enum ProposalStatus {
		Created,
		Deposited,
		Fulfilled,
		Canceled,
		Redeemed,
		Withdrawn
	}

	/**
	 * @dev Define swap item
	 */
	struct SwapItem {
		string id;
		address contractAddress;
		uint256 amount;
		address owner;
		uint256 tokenId;
		SwapItemStatus status;
		SwapItemType itemType;
	}

	/**
	 * @dev Define swap option
	 */
	struct SwapOption {
		string id;
		SwapItem[] askingItems;
	}

	/**
	 * @dev Define proposal
	 */
	struct Proposal {
		string id;
		uint256 expiredAt;
		SwapItem[] offeredItems;
		SwapOption[] swapOptions;
		/**
		 * @dev Following fields will be assigned during runtime.
		 */
		address owner;
		address fulfilledBy;
		string fulfilledByOptionId;
		ProposalStatus status;
	}
}
