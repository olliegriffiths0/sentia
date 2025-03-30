// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    constructor() ERC20("DOG42", "DOG42") Ownable(_msgSender()) {
        _mint(msg.sender, 100000000 * 10 ** 18);
    }

    error WithdrawalFailed();

    // free mint
    function freeMint(uint256 amount, address toAddress) external {
        _mint(toAddress, amount);
    }
    // free mint

    function mint1000(address toAddress) external {
        _mint(toAddress, 1000 * 10 ** 18);
    }

    // Withdraw contract funds to owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        // slither-disable-next-line arbitrary-send
        (bool success,) = msg.sender.call{value: balance}("");
        if (!success) revert WithdrawalFailed();
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
