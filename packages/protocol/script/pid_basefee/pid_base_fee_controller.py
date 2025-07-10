#!/usr/bin/env python3
"""
Python implementation of PIDBaseFeeController matching the Solidity contract.
"""

class PIDBaseFeeController:
    def __init__(self, kP, kI, kD, initial_base_fee=3349813274):
        """
        Initialize PID controller.
        
        Args:
            kP: Proportional coefficient (scaled by 1000)
            kI: Integral coefficient (scaled by 1000) 
            kD: Derivative coefficient (scaled by 1000)
            initial_base_fee: Initial base fee (default from Ethereum)
        """
        # PID coefficients (already scaled by 1000)
        self.kP = kP
        self.kI = kI
        self.kD = kD
        
        # State variables
        self.integral = 0
        self.previous_error = 0
        self.base_fee = initial_base_fee
        
        # Constants matching Solidity
        self.ERROR_DIVISOR = 1000
        self.MAX_INTEGRAL = 10**18
        self.MIN_BASE_FEE = 10**9  # 1 gwei
        self.MAX_BASE_FEE = 2**64 - 1  # uint64 max
        
    def update_base_fee(self, parent_gas_used, gas_target):
        """
        Calculate new base fee using PID control algorithm.
        
        Args:
            parent_gas_used: Gas used in parent block
            gas_target: Current gas usage target (gasLimit/2)
            
        Returns:
            New base fee
        """
        # Calculate error (can be positive or negative)
        new_error = parent_gas_used - gas_target
        
        # Update integral (accumulated error) with anti-windup
        new_integral = self.integral + new_error
        
        # Apply integral windup protection
        if new_integral > self.MAX_INTEGRAL:
            self.integral = self.MAX_INTEGRAL
        elif new_integral < -self.MAX_INTEGRAL:
            self.integral = -self.MAX_INTEGRAL
        else:
            self.integral = new_integral
            
        # Calculate derivative (rate of change of error)
        derivative = new_error - self.previous_error
        
        # Calculate PID adjustment
        # Divide by 1000 as coefficients are scaled
        adjustment = (self.kP * new_error + self.kI * self.integral + self.kD * derivative) // 1000
        
        # Update previous error for next iteration
        self.previous_error = new_error
        
        # Apply adjustment to base fee
        new_base_fee = self.base_fee + adjustment
        
        # Clamp to valid range [MIN_BASE_FEE, MAX_BASE_FEE]
        if new_base_fee <= self.MIN_BASE_FEE:
            new_base_fee = self.MIN_BASE_FEE
        elif new_base_fee > self.MAX_BASE_FEE:
            new_base_fee = self.MAX_BASE_FEE
            
        # Update base fee
        self.base_fee = int(new_base_fee)
        
        return self.base_fee
    
    def reset(self, initial_base_fee=3349813274):
        """Reset controller to initial state."""
        self.integral = 0
        self.previous_error = 0
        self.base_fee = initial_base_fee