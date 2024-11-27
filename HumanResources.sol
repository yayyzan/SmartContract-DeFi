// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;
import "./IHumanResources.sol";
import "./node_modules/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import './node_modules/@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import './node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';


abstract contract HumanResources is IHumanResources {

    address USDC = 0x0b2c639c533813f4aa9d7837caf62653d097ff85;
    address ROUTER = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;

    enum preferredPay {USDC, ETH}

    struct Employee{
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 accumulated;
        uint256 lastWithdrawalStamp;
        preferredPay preference;
    }

    address public immutable hrManagerAddress; 
    mapping(address => Employee) private employeeMap;
    address[] public employeeAddresses;
    uint256 employeeCount;

    constructor(address _hrManager){
        hrManagerAddress = _hrManager; 
        swapRouter = ISwapRouter(ROUTER);
        usdc = IERC(USDC);
    }

    modifier onlyHrManager(){
        require(msg.sender == hrManagerAddress, NotAuthorized());
        _;
    }

    modifier onlyEmployee(){
        require(employeeMap[msg.sender].employedSince != 0, NotAuthorized());
    }

    function salaryAvailable (address employee) external view returns (uint256){
        return ((block.timestamp - employeeMap[employee].lastWithdrawalStamp) / 1 weeks) * employeeMap[employee].weeklyUsdSalary;
    }

    function hrManager() external view returns (address){
        return hrManagerAddress;
    }

    function getActiveEmployeeCount() external view returns(uint256){
        return employeeCount;
    }

    function getEmployeeInfo(address employee) external view returns(uint256, uint256, uint256){
        Employee memory employeeInfo = employeeMap[employee];
        return (employeeInfo.weeklyUsdSalary, employeeInfo.employedSince, employeeInfo.terminatedAt);
    }

    function swapUSDCForEth(uint256 usdcAmount, uint256 slippage) private returns (uint256) {
        usdc.approve(address(swapRouter), usdcAmount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: USDC_ADDRESS,
            tokenOut: WETH_ADDRESS,
            fee: 500, 
            recipient: address(this),
            deadline: block.timestamp + 300,
            amountIn: usdcAmount,
            amountOutMinimum: slippage,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        return amountOut;
    } 

    function registerEmployee (address employee, uint256 weeklyUsdSalary) onlyHrManager external {
        uint256 checkEmployee = employeeMap[employee].employedSince;
        if (checkEmployee == 0){
            Employee memory newEmployee = Employee(weeklyUsdSalary, block.timestamp, 0, 0, block.timestamp, preferredPay.USDC);
            employeeMap[employee] = newEmployee;
            employeeAddresses.push(employee);
            employeeCount += 1;
            emit EmployeeRegistered(employee, weeklyUsdSalary);
        }
        else {
            revert EmployeeAlreadyRegistered();
        }
    }

    function terminateEmployee (address employee) onlyHrManager external {
        if(employeeMap[employee].employedSince  == 0){
            revert EmployeeNotRegistered();
        }
        employeeMap[employee].terminatedAt = block.timestamp;
        employeeMap[employee].employedSince = 0;
        employeeMap[employee].weeklyUsdSalary = 0;
        employeeCount -= 1;
        employeeMap[employee].accumulated = ((block.timestamp - employeeMap[employee].lastWithdrawalStamp) / 1 weeks) * employeeMap[employee].weeklyUsdSalary;
        emit EmployeeTerminated(employee);
    }

    function withdrawSalary() onlyEmployee external {
        uint256 preferredMethod = employeeMap[msg.sender].preference;
        uint256 salary = employeeMap[msg.sender].accumulated + ((block.timestamp - employeeMap[msg.sender].lastWithdrawalStamp) / 1 weeks) * employeeMap[msg.sender].weeklyUsdSalary;
        if(preferredMethod == preferredPay.ETH){
            uint256 eth = swapUSDCForEth(salary, 0.3);
            TransferHelper.safeTransferFrom(USDC, address(this), msg.sender, eth);
        } else {
            TransferHelper.safeTransferFrom(USDC, address(this), msg.sender, salary);
        }

    }

    
}
