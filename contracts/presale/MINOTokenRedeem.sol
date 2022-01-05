pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MINOTokenRedeem is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public immutable preMINO;

    address public immutable MINOAddress;

    uint256 public startTime;

    event MINOSwap(address sender, uint256 amountIn, uint256 amountOut);
    event StartTimeChanged(uint256 newStartTime);
    event MINORecovery(address recipient, uint256 recoveryAmount);

    constructor(uint256 _startTime, address _preMINO, address _MINOAddress) {
        require(block.timestamp < _startTime, "cannot set start block in the past!");
        require(_preMINO != _MINOAddress, "preMINO cannot be equal to MINO");
        require(_MINOAddress != address(0), "_MINOAddress cannot be the zero address");
        require(_preMINO != address(0), "_preMINOAddress cannot be the zero address");

        startTime = _startTime;

        preMINO = _preMINO;
        MINOAddress = _MINOAddress;
    }

    function swapPreMINOForMINO(uint256 MINOSwapAmount) external nonReentrant {
        require(block.timestamp >= startTime, "token redemption hasn't started yet, good things come to those that wait");

        uint256 pminoDecimals = ERC20(preMINO).decimals();
        uint256 MINODecimals = ERC20(MINOAddress).decimals();

        uint256 MINOSwapAmountWei = pminoDecimals > MINODecimals ?
                                        MINOSwapAmount / (10 ** (pminoDecimals - MINODecimals)) :
                                            pminoDecimals < MINODecimals ?
                                                MINOSwapAmount * (10 ** (MINODecimals - pminoDecimals)) :
                                                MINOSwapAmount;

        require(IERC20(MINOAddress).balanceOf(address(this)) >= MINOSwapAmountWei, "Not enough tokens in contract for swap");

        ERC20(preMINO).safeTransferFrom(msg.sender, BURN_ADDRESS, MINOSwapAmount);
        ERC20(MINOAddress).safeTransfer(msg.sender, MINOSwapAmountWei);

        emit MINOSwap(msg.sender, MINOSwapAmount, MINOSwapAmountWei);
    }

    function setStartTime(uint256 _newStartTime) external onlyOwner {
        require(block.timestamp < startTime, "cannot change start block if sale has already commenced");
        require(block.timestamp < _newStartTime, "cannot set start block in the past");
        startTime = _newStartTime;

        emit StartTimeChanged(_newStartTime);
    }

    // Recover MINO in case of error, only owner can use.
    function recoverMINO(address recipient, uint256 recoveryAmount) external onlyOwner {
        if (recoveryAmount > 0)
            ERC20(MINOAddress).safeTransfer(recipient, recoveryAmount);
        
        emit MINORecovery(recipient, recoveryAmount);
    }
}