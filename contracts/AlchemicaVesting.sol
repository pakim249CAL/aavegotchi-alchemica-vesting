pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AlchemicaVesting is Ownable {
  using SafeERC20 for IERC20;

  event TokensReleased(address token, uint256 amount);
  event TokenVestingRevoked(address token);

  // Beneficiary of tokens after they are released
  address private _beneficiary;

  // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
  uint256 private _cliff;
  uint256 private _start;
  uint256 private _duration;

  bool private _revocable;

  mapping (address => uint256) private _released;
  mapping (address => bool) private _revoked;
  
  function replaceBeneficiary(address newBeneficiary) external {
    require(msg.sender == _beneficiary, "Not authorized");
    _beneficiary = newBeneficiary;
  }

  /**
    * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
    * beneficiary, gradually in a linear fashion until start + duration. By then all
    * of the balance will have vested.
    * @param beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param cliffDuration duration in seconds of the cliff in which tokens will begin to vest
    * @param start the time (as Unix time) at which point vesting starts
    * @param duration duration in seconds of the period in which the tokens will vest
    * @param revocable whether the vesting is revocable or not
    */
  constructor (address beneficiary, uint256 start, uint256 cliffDuration, uint256 duration, bool revocable) public {
    require(beneficiary != address(0), "TokenVesting: beneficiary is the zero address");
    // solhint-disable-next-line max-line-length
    require(cliffDuration <= duration, "TokenVesting: cliff is longer than duration");
    require(duration > 0, "TokenVesting: duration is 0");
    // solhint-disable-next-line max-line-length
    require(start + duration > block.timestamp, "TokenVesting: final time is before current time");

    _beneficiary = beneficiary;
    _revocable = revocable;
    _duration = duration;
    _cliff = start + cliffDuration;
    _start = start;
  }

  /**
    * @return the beneficiary of the tokens.
    */
  function beneficiary() public view returns (address) {
    return _beneficiary;
  }

  /**
    * @return the cliff time of the token vesting.
    */
  function cliff() public view returns (uint256) {
    return _cliff;
  }

  /**
    * @return the start time of the token vesting.
    */
  function start() public view returns (uint256) {
    return _start;
  }

  /**
    * @return the duration of the token vesting.
    */
  function duration() public view returns (uint256) {
    return _duration;
  }

  /**
    * @return true if the vesting is revocable.
    */
  function revocable() public view returns (bool) {
    return _revocable;
  }

  /**
    * @return the amount of the token released.
    */
  function released(address token) public view returns (uint256) {
    return _released[token];
  }

  /**
    * @return true if the token is revoked.
    */
  function revoked(address token) public view returns (bool) {
    return _revoked[token];
  }

  /**
    * @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(IERC20 token) public {
    uint256 unreleased = releasableAmount(token);

    require(unreleased > 0, "TokenVesting: no tokens are due");

    _released[address(token)] = _released[address(token)] + unreleased;

    token.safeTransfer(_beneficiary, unreleased);

    emit TokensReleased(address(token), unreleased);
  }
  
  function partialRelease(IERC20 token, uint256 value) public {
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0, "TokenVesting: no tokens are due");
    require(value <= unreleased, "value is greater than unreleased amount");
    
    _released[address(token)] = _released[address(token)] + value;

    token.safeTransfer(_beneficiary, value);

    emit TokensReleased(address(token), value);
  }

  /**
    * @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(IERC20 token) public onlyOwner {
    require(_revocable, "TokenVesting: cannot revoke");
    require(!_revoked[address(token)], "TokenVesting: token already revoked");

    uint256 balance = token.balanceOf(address(this));

    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance - unreleased;

    _revoked[address(token)] = true;

    token.safeTransfer(owner(), refund);

    emit TokenVestingRevoked(address(token));
  }

  /**
    * @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(IERC20 token) public view returns (uint256) {
    return _vestedAmount(token) - _released[address(token)];
  }

  /**
    * @dev Calculates the amount that has already vested.
    * @param token ERC20 token which is being vested
    */
  function _vestedAmount(IERC20 token) private view returns (uint256) {
    uint256 currentBalance = token.balanceOf(address(this));
    uint256 totalBalance = currentBalance + _released[address(token)];

    if (block.timestamp < _cliff) {
      return 0;
    } else if (block.timestamp >= _start + _duration || _revoked[address(token)]) {
      return totalBalance;
    } else {
      // TODO: Vesting formula TBD
      return totalBalance * (block.timestamp - _start) / _duration;
    }
  }
}