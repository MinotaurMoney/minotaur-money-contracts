// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


// AddLiquidityHelper, allows anyone to add or remove Mino liquidity tax free
// Also allows the Mino Token to do buy backs tax free via an external contract.
contract AddLiquidityHelper is ReentrancyGuard, Ownable {
    using SafeERC20 for ERC20;

    address public minoAddress;

    IUniswapV2Router02 public immutable minoSwapRouter;

    // To receive ETH when swapping
    receive() external payable {}

    event SetMinoAddress(address minoAddress);

    /**
     * @notice Constructs the AddLiquidityHelper contract.
     */
    constructor(address _router) public  {
        require(_router != address(0), "_router is the zero address");
        minoSwapRouter = IUniswapV2Router02(_router);
    }

    function addMinoETHLiquidity(uint256 nativeAmount) external payable nonReentrant {
        require(msg.value > 0, "!sufficient funds");

        ERC20(minoAddress).safeTransferFrom(msg.sender, address(this), nativeAmount);

        // approve token transfer to cover all possible scenarios
        ERC20(minoAddress).approve(address(minoSwapRouter), nativeAmount);

        // add the liquidity
        minoSwapRouter.addLiquidityETH{value: msg.value}(
            minoAddress,
            nativeAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );

        if (address(this).balance > 0) {
            // not going to require/check return value of this transfer as reverting behaviour is undesirable.
            payable(address(msg.sender)).call{value: address(this).balance}("");
        }

        uint256 minoBalance = ERC20(minoAddress).balanceOf(address(this));

        if (minoBalance > 0)
            ERC20(minoAddress).transfer(msg.sender, minoBalance);
    }

    function addMinoLiquidity(address baseTokenAddress, uint256 baseAmount, uint256 nativeAmount) external nonReentrant {
        ERC20(baseTokenAddress).safeTransferFrom(msg.sender, address(this), baseAmount);
        ERC20(minoAddress).safeTransferFrom(msg.sender, address(this), nativeAmount);

        // approve token transfer to cover all possible scenarios
        ERC20(baseTokenAddress).approve(address(minoSwapRouter), baseAmount);
        ERC20(minoAddress).approve(address(minoSwapRouter), nativeAmount);

        // add the liquidity
        minoSwapRouter.addLiquidity(
            baseTokenAddress,
            minoAddress,
            baseAmount,
            nativeAmount ,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );

        if (ERC20(baseTokenAddress).balanceOf(address(this)) > 0)
            ERC20(baseTokenAddress).safeTransfer(msg.sender, ERC20(baseTokenAddress).balanceOf(address(this)));

        if (ERC20(minoAddress).balanceOf(address(this)) > 0)
            ERC20(minoAddress).transfer(msg.sender, ERC20(minoAddress).balanceOf(address(this)));
    }

    function removeMinoLiquidity(address baseTokenAddress, uint256 liquidity) external nonReentrant {
        address lpTokenAddress = IUniswapV2Factory(minoSwapRouter.factory()).getPair(baseTokenAddress, minoAddress);
        require(lpTokenAddress != address(0), "pair hasn't been created yet, so can't remove liquidity!");

        ERC20(lpTokenAddress).safeTransferFrom(msg.sender, address(this), liquidity);
        // approve token transfer to cover all possible scenarios
        ERC20(lpTokenAddress).approve(address(minoSwapRouter), liquidity);

        // add the liquidity
        minoSwapRouter.removeLiquidity(
            baseTokenAddress,
            minoAddress,
            liquidity,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );
    }

    /// @dev Swap tokens for eth
    function swapTokensForEth(address saleTokenAddress, uint256 tokenAmount) internal {
        // generate the minoSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = saleTokenAddress;
        path[1] = minoSwapRouter.WETH();

        ERC20(saleTokenAddress).approve(address(minoSwapRouter), tokenAmount);

        // make the swap
        minoSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }


    function swapETHForTokens(uint256 ethAmount, address wantedTokenAddress) internal {
        require(address(this).balance >= ethAmount, "insufficient matic provided!");
        require(wantedTokenAddress != address(0), "wanted token address can't be the zero address!");

        // generate the minoSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = minoSwapRouter.WETH();
        path[1] = wantedTokenAddress;

        // make the swap
        minoSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0,
            path,
            // cannot send tokens to the token contract of the same type as the output token
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev set the mino address.
     * Can only be called by the current owner.
     */
    function setMinoAddress(address _minoAddress) external onlyOwner {
        require(_minoAddress != address(0), "_minoddress is the zero address");
        require(minoAddress == address(0), "minoAddress already set!");

        minoAddress = _minoAddress;

        emit SetMinoAddress(minoAddress);
    }
}
