pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// MINOPresale
contract MINOPresale is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public constant daiAddress = 0xF2001B145b43032AAF5Ee2884e456CCd805F677D;

    uint256 public salePriceE35 = 0.16 * 1e35;

    uint256 public constant MINOMaximumSupply = 40 * 1e3 * 1e9;

    uint256 public constant maxMINOPurchase = 800 * 1e9;

    // We use a counter to defend against people sending MINO back
    uint256 public MINORemaining = MINOMaximumSupply;

    uint256 threeDays = 3600 * 24 * 3;

    uint256 public startTime;
    uint256 public endTime;

    mapping(address => uint256) public userMINOTally;

    bool public hasRetrievedUnsoldPresale = false;

    address public immutable MINOAddress;

    address public immutable treasuryAddress;


    event MINOPurchased(address sender, uint256 maticSpent, uint256 MINOReceived);
    event StartTimeChanged(uint256 newStartTime, uint256 newEndTime);
    event SalePriceE35Changed(uint256 newSalePriceE5);
    event RetrieveUnclaimedTokens(uint256 MINOAmount);

    constructor(uint256 _startTime, address _treasuryAddress, address _MINOAddress) {
        require(block.timestamp < _startTime, "cannot set start block in the past!");
        require(_treasuryAddress != _MINOAddress, "_treasuryAddress cannot be equal to _MINOAddress");
        require(_treasuryAddress != address(0), "_MINOAddress cannot be the zero address");
        require(_MINOAddress != address(0), "_MINOAddress cannot be the zero address");
    
        startTime = _startTime;
        endTime   = _startTime + threeDays;

        MINOAddress = _MINOAddress;
        treasuryAddress = _treasuryAddress;
    }

    function buyMINO(uint256 daiToSpend) external nonReentrant {
        //require(msg.sender != treasuryAddress, "treasury address cannot partake in presale");
        require(block.timestamp >= startTime, "presale hasn't started yet, good things come to those that wait");
        require(block.timestamp < endTime, "presale has ended, come back next time!");
        require(MINORemaining > 0, "No more MINO remaining! Come back next time!");
        require(ERC20(MINOAddress).balanceOf(address(this)) > 0, "No more MINO left! Come back next time!");
        require(daiToSpend > 0, "not enough dai provided");

        // maybe useful if we allow people to buy a second time
        require(userMINOTally[msg.sender] < maxMINOPurchase, "user has already purchased too much MINO");

        uint256 originalMINOAmountUnscaled = (daiToSpend * salePriceE35) / 1e35;

        uint256 daiDecimals = ERC20(daiAddress).decimals();
        uint256 MINODecimals = ERC20(MINOAddress).decimals();

        uint256 originalMINOAmount = daiDecimals == MINODecimals ?
                                        originalMINOAmountUnscaled :
                                            daiDecimals > MINODecimals ?
                                                originalMINOAmountUnscaled / (10 ** (daiDecimals - MINODecimals)) :
                                                originalMINOAmountUnscaled * (10 ** (MINODecimals - daiDecimals));

        uint256 MINOPurchaseAmount = originalMINOAmount;

        if (MINOPurchaseAmount > maxMINOPurchase)
            MINOPurchaseAmount = maxMINOPurchase;

        // if we dont have enough left, give them the rest.
        if (MINORemaining < MINOPurchaseAmount)
            MINOPurchaseAmount = MINORemaining;

        require(MINOPurchaseAmount > 0, "user cannot purchase 0 MINO");

        // shouldn't be possible to fail these asserts.
        assert(MINOPurchaseAmount <= MINORemaining);
        require(MINOPurchaseAmount <= ERC20(MINOAddress).balanceOf(address(this)), "not enough MINO in contract");

        ERC20(MINOAddress).safeTransfer(msg.sender, MINOPurchaseAmount);

        MINORemaining = MINORemaining - MINOPurchaseAmount;
        userMINOTally[msg.sender] = userMINOTally[msg.sender] + MINOPurchaseAmount;

        uint256 daiSpent = daiToSpend;
        if (MINOPurchaseAmount < originalMINOAmount) {
            daiSpent = (MINOPurchaseAmount * daiToSpend) / originalMINOAmount;
        }

        if (daiSpent > 0)
            ERC20(daiAddress).safeTransferFrom(msg.sender, treasuryAddress, daiSpent);

        emit MINOPurchased(msg.sender, daiSpent, MINOPurchaseAmount);
    }

    function sendUnclaimedsToTreasuryAddress() external onlyOwner {
        require(block.timestamp > endTime, "presale hasn't ended yet!");
        require(!hasRetrievedUnsoldPresale, "can only recover unsold tokens once!");

        hasRetrievedUnsoldPresale = true;

        uint256 MINORemainingBalance = ERC20(MINOAddress).balanceOf(address(this));

        require(MINORemainingBalance > 0, "no more MINO remaining! you sold out!");

        ERC20(MINOAddress).safeTransfer(treasuryAddress, MINORemainingBalance);

        emit RetrieveUnclaimedTokens(MINORemainingBalance);
    }

    function setStartTime(uint256 _newStartTime) external onlyOwner {
        require(block.timestamp < startTime, "cannot change start block if sale has already commenced");
        require(block.timestamp < _newStartTime, "cannot set start block in the past");
        startTime = _newStartTime;
        endTime   = _newStartTime + threeDays;

        emit StartTimeChanged(_newStartTime, endTime);
    }

    function setSalePriceE35(uint256 _newSalePriceE35) external onlyOwner {
        //require(block.timestamp < startTime - (3600 * 4), "cannot change price 4 hours before start block");
        require(_newSalePriceE35 >= 0.004 * 1e35, "new price can't be too low");
        require(_newSalePriceE35 <= 0.4 * 1e35, "new price can't be too high");
        salePriceE35 = _newSalePriceE35;

        emit SalePriceE35Changed(salePriceE35);
    }
}