--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
--Date        : Fri Aug 14 11:10:38 2026
--Host        : Admin-PC running 64-bit major release  (build 9200)
--Command     : generate_target SoC_wrapper.bd
--Design      : SoC_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity SoC_wrapper is
end SoC_wrapper;

architecture STRUCTURE of SoC_wrapper is
  component SoC is
  end component SoC;
begin
SoC_i: component SoC
 ;
end STRUCTURE;
