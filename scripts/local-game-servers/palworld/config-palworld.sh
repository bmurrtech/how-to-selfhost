#!/bin/bash
# config-palworld.sh — Interactive wizard to configure PalWorldSettings.ini.
# Intended to run AFTER server creation; use when you want to modify config on an existing server.
# Stops the Palworld service before applying changes (required; live edits are overwritten on server stop).
# Usage: sudo PAL_INSTALL_DIR=/home/steam/palserver ./config-palworld.sh
# See: https://docs.palworldgame.com/settings-and-operation/configuration

set -euo pipefail

PAL_INSTALL_DIR="${PAL_INSTALL_DIR:-/home/steam/palserver}"
CONFIG_DIR="$PAL_INSTALL_DIR/Pal/Saved/Config/LinuxServer"
CONFIG_FILE="$CONFIG_DIR/PalWorldSettings.ini"

# Normalize and validate float: trim, collapse spaces (e.g. "1 . 2" -> 1.2)
normalize_float() {
  local v
  v="$(echo "$1" | tr -d ' \t' | tr -s '.' '.')"
  if [[ "$v" =~ ^-?[0-9]+\.?[0-9]*$ ]] || [[ "$v" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
    echo "$v"
    return 0
  fi
  return 1
}

# Clamp float to [min, max] and output (for range validation). Uses awk (no bc).
clamp_float() {
  local val="$1" min="$2" max="$3"
  local v
  v="$(normalize_float "$val" 2>/dev/null)" || return 1
  v="$(awk -v v="$v" -v min="$min" -v max="$max" 'BEGIN{if(v<min)v=min; if(v>max)v=max; printf "%f", v}')"
  echo "$v"
  return 0
}

normalize_int() {
  local v
  v="$(echo "$1" | tr -d ' \t')"
  if [[ "$v" =~ ^-?[0-9]+$ ]]; then
    echo "$v"
    return 0
  fi
  return 1
}

# Accept 1=Off/2=On, 0/1, true/false, yes/no, on/off (case-insensitive)
normalize_bool() {
  local v
  v="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' \t')"
  case "$v" in
    2|true|yes|on) echo "True"; return 0 ;;
    1|0|false|no|off) echo "False"; return 0 ;;
    *) return 1 ;;
  esac
}

prompt_float() {
  local key="$1" desc="$2" default="$3" tip="$4"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Tip: $tip"
    read -r -p "  [$key] ($default): " val
    val="${val:-$default}"
    val="$(normalize_float "$val" 2>/dev/null)" && break
    echo "  Invalid. Enter a number (e.g. 1.0 or 1.5)."
  done
  echo "$key=$val"
}

prompt_int() {
  local key="$1" desc="$2" default="$3" tip="$4"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Tip: $tip"
    read -r -p "  [$key] ($default): " val
    val="${val:-$default}"
    val="$(normalize_int "$val" 2>/dev/null)" && break
    echo "  Invalid. Enter an integer (e.g. 16 or 0)."
  done
  echo "$key=$val"
}

# Float with min/max range (clamped). Tip should include range, e.g. "Float 0.1-5."
prompt_float_range() {
  local key="$1" desc="$2" default="$3" min="$4" max="$5" tip="$6"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Options: number from $min to $max. Default: $default"
    read -r -p "  Value ($min-$max, default $default): " val
    val="${val:-$default}"
    val="$(clamp_float "$val" "$min" "$max" 2>/dev/null)" && break
    echo "  Invalid. Enter a number between $min and $max (e.g. $default)."
  done
  echo "$key=$val"
}

# Integer with min/max range (clamped)
prompt_int_range() {
  local key="$1" desc="$2" default="$3" min="$4" max="$5" tip="$6"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Options: integer from $min to $max. Default: $default"
    read -r -p "  Value ($min-$max, default $default): " val
    val="${val:-$default}"
    val="$(normalize_int "$val" 2>/dev/null)" || true
    if [[ -n "$val" ]] && [[ "$val" -ge "$min" ]] && [[ "$val" -le "$max" ]]; then
      break
    fi
    val="$default"
    break
  done
  echo "$key=$val"
}

prompt_bool() {
  local key="$1" desc="$2" default="$3" tip="$4"
  local val out
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Options: 1=Off 2=On (or off/on, 0/1, false/true). Default: $default"
    read -r -p "  [1=Off 2=On] (default $default): " val
    val="${val:-$default}"
    out="$(normalize_bool "$val" 2>/dev/null)" && break
    echo "  Invalid. Enter 1/2, Off/On, 0/1, or True/False."
  done
  echo "$key=$out"
}

prompt_string() {
  local key="$1" desc="$2" default="$3" tip="$4"
  echo ""
  echo "--- $key ---"
  echo "  $desc"
  echo "  Tip: $tip"
  read -r -p "  [$key] ($default): " val
  val="${val:-$default}"
  # Escape quotes for INI
  val="${val//\\/\\\\}"
  val="${val//\"/\\\"}"
  echo "$key=\"$val\""
}

prompt_enum() {
  local key="$1" desc="$2" default="$3" tip="$4" opts="$5"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  $desc"
    echo "  Tip: $tip Options: $opts"
    read -r -p "  [$key] ($default): " val
    val="${val:-$default}"
    val="$(echo "$val" | tr '[:upper:]' '[:lower:]' | tr -d ' \t')"
    case "$val" in
      none|normal|difficult|item|itemandequipment|all|region) ;;
      *) val="" ;;
    esac
    if [[ -n "$val" ]]; then
      # Output with first letter capital for game
      val="$(echo "$val" | sed 's/^./\U&/')"
      [[ "$val" == "Itemandequipment" ]] && val="ItemAndEquipment"
      [[ "$val" == "Itemandequip" ]] && val="ItemAndEquipment"
      echo "$key=$val"
      return 0
    fi
    echo "  Invalid. Choose from: $opts"
  done
}

# DeathPenalty enum: None, Item, ItemAndEquipment, All (default Item = drop all items except equipment)
prompt_death_penalty() {
  local default="${1:-Item}"
  local key="DeathPenalty"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  Death penalty on player death."
    echo "  Options: 1=No Drops  2=Drop all items except equipment  3=Drop all items  4=Drop all items and all Pals. Default: 2"
    read -r -p "  [1-4 or name] (default 2): " val
    val="${val:-$default}"
    val="$(echo "$val" | tr '[:upper:]' '[:lower:]' | tr -d ' \t')"
    case "$val" in
      1|none) echo "DeathPenalty=None"; return 0 ;;
      2|item) echo "DeathPenalty=Item"; return 0 ;;
      3|itemandequipment) echo "DeathPenalty=ItemAndEquipment"; return 0 ;;
      4|all) echo "DeathPenalty=All"; return 0 ;;
    esac
    echo "  Invalid. Enter 1-4 or: None, Item, ItemAndEquipment, All"
  done
}

prompt_death_penalty_item_default() {
  prompt_death_penalty "Item"
}

# RandomizerType: None, Region, All
prompt_randomizer_type() {
  local key="RandomizerType"
  local val
  while true; do
    echo ""
    echo "--- $key ---"
    echo "  Pal spawn randomization. Options: 1=None  2=Region (per region)  3=All (fully random). Default: 1"
    read -r -p "  [1-3 or name] (default 1): " val
    val="${val:-1}"
    val="$(echo "$val" | tr '[:upper:]' '[:lower:]' | tr -d ' \t')"
    case "$val" in
      1|none) echo "RandomizerType=None"; return 0 ;;
      2|region) echo "RandomizerType=Region"; return 0 ;;
      3|all) echo "RandomizerType=All"; return 0 ;;
    esac
    echo "  Invalid. Enter 1-3 or: None, Region, All"
  done
}

# CrossplayPlatforms: (Steam,Xbox,PS5,Mac) - keep parentheses
prompt_crossplay() {
  local key="CrossplayPlatforms" desc="Allowed platforms to connect. Use parentheses, e.g. (Steam,Xbox,PS5,Mac)."
  local default="(Steam,Xbox,PS5,Mac)" tip="String with parentheses, e.g. (Steam,Xbox,PS5,Mac)"
  echo ""
  echo "--- $key ---"
  echo "  $desc"
  echo "  Tip: $tip"
  read -r -p "  [$key] ($default): " val
  val="${val:-$default}"
  val="${val//\\/\\\\}"
  val="${val//\"/\\\"}"
  echo "CrossplayPlatforms=\"$val\""
}

# ----- Main -----
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root (sudo) to stop the service and write config."
  exit 1
fi

echo "Stopping palworld service so config changes are not overwritten..."
systemctl stop palworld.service 2>/dev/null || true

if [[ ! -d "$PAL_INSTALL_DIR" ]]; then
  echo "Install directory not found: $PAL_INSTALL_DIR"
  echo "Set PAL_INSTALL_DIR if you used a different path (e.g. PAL_INSTALL_DIR=/home/steam/palserver)."
  exit 1
fi

mkdir -p "$CONFIG_DIR"

echo ""
echo "=============================================="
echo "Palworld server configuration wizard"
echo "=============================================="
echo ""

read -r -p "Advanced mode (fine-grained control of all settings)? [N/y]: " advanced_mode
if [[ ! "${advanced_mode:-n}" =~ ^[Yy] ]]; then
  # Simple difficulty mode: 1=casual, 2=normal, 3=hard, 4=hardcore
  echo ""
  echo "Choose difficulty preset: 1=casual  2=normal  3=hard  4=hardcore"
  echo "  casual   - Easier rates, less penalty, fast travel on"
  echo "  normal   - Balanced defaults"
  echo "  hard     - Harder rates, more penalty"
  echo "  hardcore - No respawn, permanent loss (bHardcore, bPalLost, etc.)"
  read -r -p "Enter 1-4 or name (default 2): " difficulty
  difficulty="$(echo "${difficulty:-2}" | tr '[:upper:]' '[:lower:]' | tr -d ' \t')"
  case "$difficulty" in
    1|casual)   DIFF_PRESET="casual" ;;
    2|normal)   DIFF_PRESET="normal" ;;
    3|hard)     DIFF_PRESET="hard" ;;
    4|hardcore) DIFF_PRESET="hardcore" ;;
    *)          DIFF_PRESET="normal" ;;
  esac
  # Build preset OptionSettings (source: official params, preset values)
  case "$DIFF_PRESET" in
    casual)
      OPTIONS="ServerName=\"My Palworld Server\",ServerDescription=\"\",ServerPassword=\"\",AdminPassword=\"\",ServerPlayerMaxNum=16,ChatPostLimitPerMinute=10,bIsShowJoinLeftMessage=True,bAllowClientMod=False,bIsUseBackupSaveData=False,CrossplayPlatforms=\"(Steam,Xbox,PS5,Mac)\",bIsPvP=False,DeathPenalty=None,bPalLost=False,BlockRespawnTime=60.000000,bEnableInvaderEnemy=True,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=2.000000,PalCaptureRate=1.500000,PalSpawnNumRate=1.000000,PalDamageRateAttack=1.000000,PalDamageRateDefense=1.000000,PlayerDamageRateAttack=1.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=0.500000,PlayerStaminaDecreaceRate=0.500000,PlayerAutoHPRegeneRate=1.500000,PlayerAutoHpRegeneRateInSleep=1.500000,PalStomachDecreaceRate=0.500000,PalStaminaDecreaceRate=0.500000,PalAutoHPRegeneRate=1.500000,PalAutoHpRegeneRateInSleep=3.000000,BuildObjectDamageRate=0.500000,BuildObjectDeteriorationDamageRate=0.000000,CollectionDropRate=2.000000,CollectionObjectHpRate=1.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=2.000000,DropItemMaxNum=3000,DropItemAliveMaxHours=1.000000,BaseCampMaxNum=128,BaseCampWorkerMaxNum=15,BaseCampMaxNumInGuild=6,GuildPlayerMaxNum=20,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,MaxBuildingLimitNum=10000,bEnableFastTravel=True,bEnableFastTravelOnlyBaseCamp=False,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bHardcore=False,bShowPlayerList=True,bAllowGlobalPalboxExport=True,bAllowGlobalPalboxImport=False,RandomizerType=None,RandomizerSeed=\"\",bIsRandomizerPalLevelRandom=False,PalEggDefaultHatchingTime=1.000000,SupplyDropSpan=200,WorkSpeedRate=1.000000,ItemWeightRate=0.500000,EquipmentDurabilityDamageRate=1.000000,ItemCorruptionMultiplier=1.000000,ServerReplicatePawnCullDistance=15000.000000"
      ;;
    normal)
      OPTIONS="ServerName=\"My Palworld Server\",ServerDescription=\"\",ServerPassword=\"\",AdminPassword=\"\",ServerPlayerMaxNum=16,ChatPostLimitPerMinute=10,bIsShowJoinLeftMessage=True,bAllowClientMod=False,bIsUseBackupSaveData=False,CrossplayPlatforms=\"(Steam,Xbox,PS5,Mac)\",bIsPvP=False,DeathPenalty=Item,bPalLost=False,BlockRespawnTime=300.000000,bEnableInvaderEnemy=True,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=5.000000,PalCaptureRate=2.000000,PalSpawnNumRate=1.500000,PalDamageRateAttack=1.500000,PalDamageRateDefense=1.500000,PlayerDamageRateAttack=2.000000,PlayerDamageRateDefense=1.000000,PlayerStomachDecreaceRate=1.000000,PlayerStaminaDecreaceRate=1.000000,PlayerAutoHPRegeneRate=1.000000,PlayerAutoHpRegeneRateInSleep=1.000000,PalStomachDecreaceRate=0.500000,PalStaminaDecreaceRate=0.500000,PalAutoHPRegeneRate=1.000000,PalAutoHpRegeneRateInSleep=3.000000,BuildObjectDamageRate=1.000000,BuildObjectDeteriorationDamageRate=0.000000,CollectionDropRate=2.000000,CollectionObjectHpRate=2.000000,CollectionObjectRespawnSpeedRate=1.000000,EnemyDropItemRate=2.000000,DropItemMaxNum=3000,DropItemAliveMaxHours=1.000000,BaseCampMaxNum=128,BaseCampWorkerMaxNum=30,BaseCampMaxNumInGuild=6,GuildPlayerMaxNum=20,bAutoResetGuildNoOnlinePlayers=False,AutoResetGuildTimeNoOnlinePlayers=72.000000,MaxBuildingLimitNum=10000,bEnableFastTravel=True,bEnableFastTravelOnlyBaseCamp=False,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bHardcore=False,bShowPlayerList=True,bAllowGlobalPalboxExport=True,bAllowGlobalPalboxImport=False,RandomizerType=None,RandomizerSeed=\"\",bIsRandomizerPalLevelRandom=False,PalEggDefaultHatchingTime=1.000000,SupplyDropSpan=200,WorkSpeedRate=1.000000,ItemWeightRate=0.500000,EquipmentDurabilityDamageRate=1.000000,ItemCorruptionMultiplier=1.000000,ServerReplicatePawnCullDistance=15000.000000"
      ;;
    hard)
      OPTIONS="ServerName=\"My Palworld Server\",ServerDescription=\"\",ServerPassword=\"\",AdminPassword=\"\",ServerPlayerMaxNum=16,ChatPostLimitPerMinute=10,bIsShowJoinLeftMessage=True,bAllowClientMod=False,bIsUseBackupSaveData=False,CrossplayPlatforms=\"(Steam,Xbox,PS5,Mac)\",bIsPvP=False,DeathPenalty=ItemAndEquipment,bPalLost=False,BlockRespawnTime=600.000000,bEnableInvaderEnemy=True,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=1.000000,PalCaptureRate=0.500000,PalSpawnNumRate=1.000000,PalDamageRateAttack=2.000000,PalDamageRateDefense=0.500000,PlayerDamageRateAttack=0.500000,PlayerDamageRateDefense=2.000000,PlayerStomachDecreaceRate=2.000000,PlayerStaminaDecreaceRate=2.000000,PlayerAutoHPRegeneRate=0.500000,PlayerAutoHpRegeneRateInSleep=0.500000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=0.500000,PalAutoHpRegeneRateInSleep=1.000000,BuildObjectDamageRate=2.000000,BuildObjectDeteriorationDamageRate=1.000000,CollectionDropRate=0.500000,CollectionObjectHpRate=2.000000,CollectionObjectRespawnSpeedRate=2.000000,EnemyDropItemRate=0.500000,DropItemMaxNum=2000,DropItemAliveMaxHours=0.500000,BaseCampMaxNum=64,BaseCampWorkerMaxNum=10,BaseCampMaxNumInGuild=4,GuildPlayerMaxNum=20,bAutoResetGuildNoOnlinePlayers=True,AutoResetGuildTimeNoOnlinePlayers=24.000000,MaxBuildingLimitNum=2000,bEnableFastTravel=True,bEnableFastTravelOnlyBaseCamp=True,bIsStartLocationSelectByMap=True,bExistPlayerAfterLogout=False,bHardcore=False,bShowPlayerList=True,bAllowGlobalPalboxExport=False,bAllowGlobalPalboxImport=False,RandomizerType=None,RandomizerSeed=\"\",bIsRandomizerPalLevelRandom=False,PalEggDefaultHatchingTime=72.000000,SupplyDropSpan=300,WorkSpeedRate=0.500000,ItemWeightRate=2.000000,EquipmentDurabilityDamageRate=2.000000,ItemCorruptionMultiplier=2.000000,ServerReplicatePawnCullDistance=10000.000000"
      ;;
    hardcore)
      OPTIONS="ServerName=\"My Palworld Server\",ServerDescription=\"\",ServerPassword=\"\",AdminPassword=\"\",ServerPlayerMaxNum=16,ChatPostLimitPerMinute=10,bIsShowJoinLeftMessage=True,bAllowClientMod=False,bIsUseBackupSaveData=True,CrossplayPlatforms=\"(Steam,Xbox,PS5,Mac)\",bIsPvP=False,DeathPenalty=All,bPalLost=True,BlockRespawnTime=0.000000,bEnableInvaderEnemy=True,DayTimeSpeedRate=1.000000,NightTimeSpeedRate=1.000000,ExpRate=0.500000,PalCaptureRate=0.500000,PalSpawnNumRate=1.000000,PalDamageRateAttack=2.000000,PalDamageRateDefense=0.500000,PlayerDamageRateAttack=0.500000,PlayerDamageRateDefense=2.000000,PlayerStomachDecreaceRate=2.000000,PlayerStaminaDecreaceRate=2.000000,PlayerAutoHPRegeneRate=0.200000,PlayerAutoHpRegeneRateInSleep=0.500000,PalStomachDecreaceRate=1.000000,PalStaminaDecreaceRate=1.000000,PalAutoHPRegeneRate=0.200000,PalAutoHpRegeneRateInSleep=0.500000,BuildObjectDamageRate=2.000000,BuildObjectDeteriorationDamageRate=2.000000,CollectionDropRate=0.500000,CollectionObjectHpRate=2.000000,CollectionObjectRespawnSpeedRate=2.000000,EnemyDropItemRate=0.500000,DropItemMaxNum=1500,DropItemAliveMaxHours=0.500000,BaseCampMaxNum=32,BaseCampWorkerMaxNum=10,BaseCampMaxNumInGuild=3,GuildPlayerMaxNum=10,bAutoResetGuildNoOnlinePlayers=True,AutoResetGuildTimeNoOnlinePlayers=12.000000,MaxBuildingLimitNum=500,bEnableFastTravel=False,bEnableFastTravelOnlyBaseCamp=True,bIsStartLocationSelectByMap=False,bExistPlayerAfterLogout=True,bHardcore=True,bCharacterRecreateInHardcore=True,bShowPlayerList=True,bAllowGlobalPalboxExport=False,bAllowGlobalPalboxImport=False,RandomizerType=None,RandomizerSeed=\"\",bIsRandomizerPalLevelRandom=False,PalEggDefaultHatchingTime=120.000000,SupplyDropSpan=600,WorkSpeedRate=0.500000,ItemWeightRate=2.000000,EquipmentDurabilityDamageRate=2.000000,ItemCorruptionMultiplier=2.000000,ServerReplicatePawnCullDistance=8000.000000"
      ;;
  esac
  {
    echo "[/Script/Pal.PalGameWorldSettings]"
    echo "OptionSettings=($OPTIONS)"
  } > "$CONFIG_FILE"
  chown steam:steam "$CONFIG_FILE"
  echo ""
  echo "Config written ($DIFF_PRESET preset): $CONFIG_FILE"
  echo ""
  read -r -p "Start palworld service now? [Y/n]: " start_now
  if [[ "${start_now:-y}" =~ ^[Yy] ]]; then
    systemctl start palworld.service
    echo "Palworld service started."
  else
    echo "Start manually when ready: sudo systemctl start palworld"
  fi
  exit 0
fi

# --- Advanced mode: full wizard (Difficulty=Custom). Press Enter to accept [default]. ---
echo "Difficulty set to Custom. Fine-grained settings below."
echo ""

OUTPUT=""

# --- Server management ---
echo "=== Server management ==="
OUTPUT="$OUTPUT"$'\n'"$(prompt_string "ServerName" "Server name shown in the list." "My Palworld Server" "Any string.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_string "ServerDescription" "Server description." "" "Any string.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_string "ServerPassword" "Password required to join (empty = no password)." "" "String or leave empty.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_string "AdminPassword" "Password for admin privileges (ingame)." "" "String.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int "ServerPlayerMaxNum" "Maximum number of players who can join." "16" "Integer (e.g. 4–32).")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int "ChatPostLimitPerMinute" "Max chat messages per minute per player." "10" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bIsShowJoinLeftMessage" "Show in-game messages when players join/leave." "True" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bAllowClientMod" "Allow players with mods to join." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bIsUseBackupSaveData" "Enable world backups (increases disk load)." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_crossplay)"

# --- PvP / combat ---
echo ""
echo "=== PvP and combat ==="
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bIsPvP" "Enable PvP (player vs player damage)." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_death_penalty_item_default)"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bPalLost" "Permanently lose Pals on death (Hardcore Pal Mode)." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float "BlockRespawnTime" "Cooldown before respawn after death (seconds)." "300.000000" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bEnableInvaderEnemy" "Enable Raid Events (Invader)." "True" "On/Off or True/False.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bEnablePredatorBossPal" "Enable Predator Pals." "True" "On/Off or True/False.")"

# --- Autosave preset ---
prompt_autosave() {
  echo ""
  echo "--- AutoSaveSpan ---"
  echo "  Autosave interval. Options: 1=30s  2=1m  3=5m  4=10m  5=15m  6=30m. Default: 3 (5m)"
  read -r -p "  Enter 1-6 (default 3): " choice
  choice="${choice:-3}"
  case "$(echo "$choice" | tr -d ' \t')" in
    1) echo "AutoSaveSpan=30.000000"; return 0 ;;
    2) echo "AutoSaveSpan=60.000000"; return 0 ;;
    3) echo "AutoSaveSpan=300.000000"; return 0 ;;
    4) echo "AutoSaveSpan=600.000000"; return 0 ;;
    5) echo "AutoSaveSpan=900.000000"; return 0 ;;
    6) echo "AutoSaveSpan=1800.000000"; return 0 ;;
    *) echo "AutoSaveSpan=300.000000"; return 0 ;;
  esac
}

# --- Time and rates (with user ranges/defaults) ---
echo ""
echo "=== Time and rates ==="
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "DayTimeSpeedRate" "Day time speed (larger = shorter days)." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "NightTimeSpeedRate" "Night time speed (larger = shorter nights)." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_autosave)"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "ExpRate" "EXP gain multiplier." "5" "0.1" "20" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalCaptureRate" "Pal capture rate multiplier." "2" "0.5" "2" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalSpawnNumRate" "Pal appearance rate (affects performance)." "1.5" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalDamageRateAttack" "Damage from Pals multiplier." "1.5" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalDamageRateDefense" "Damage to Pals multiplier." "1.5" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalStomachDecreaceRate" "Pal hunger depletion rate." "0.5" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalStaminaDecreaceRate" "Pal stamina depletion rate." "0.5" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalAutoHPRegeneRate" "Pal auto HP regen rate." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalAutoHpRegeneRateInSleep" "Pal HP regen in Palbox." "3" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerDamageRateAttack" "Damage from players multiplier." "2" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerDamageRateDefense" "Damage to players multiplier." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerStomachDecreaceRate" "Player hunger depletion rate." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerStaminaDecreaceRate" "Player stamina depletion rate." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerAutoHPRegeneRate" "Player auto HP regen rate." "1" "0.1" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PlayerAutoHpRegeneRateInSleep" "Player sleep HP regen rate." "1" "0.1" "5" "Float.")"

# --- Building and collection (ranges) ---
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "BuildObjectDamageRate" "Damage to structure multiplier." "1" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "BuildObjectDeteriorationDamageRate" "Structure deterioration rate." "0" "0" "10" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int_range "DropItemMaxNum" "Maximum number of dropped items in world." "3000" "0" "5000" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "CollectionDropRate" "Gatherable items multiplier." "2" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "CollectionObjectHpRate" "Gatherable objects health multiplier." "2" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "CollectionObjectRespawnSpeedRate" "Gatherable respawn multiplier (smaller = faster)." "1" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "EnemyDropItemRate" "Dropped items multiplier." "2" "0.5" "3" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float "DropItemAliveMaxHours" "Hours until dropped items despawn." "1.000000" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "ItemWeightRate" "Item weight multiplier." "0.5" "0" "10" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "ItemCorruptionMultiplier" "Item decay rate multiplier." "1" "0.1" "10" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "EquipmentDurabilityDamageRate" "Equipment durability loss multiplier." "1" "0" "5" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int_range "SupplyDropSpan" "Meteorite/Supplies drop interval (minutes)." "200" "1" "999" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "PalEggDefaultHatchingTime" "Time (h) to incubate Massive Egg. Other eggs need time too." "1" "0" "240" "Float.")"

# --- Max structures per base preset ---
prompt_max_structures() {
  echo ""
  echo "--- MaxBuildingLimitNum ---"
  echo "  Maximum number of structures per base. Options: 1=400  2=500  3=2000  4=5000  5=10000  6=No limit. Default: 5 (10000)"
  read -r -p "  Enter 1-6 (default 5): " choice
  choice="${choice:-5}"
  case "$(echo "$choice" | tr -d ' \t')" in
    1) echo "MaxBuildingLimitNum=400"; return 0 ;;
    2) echo "MaxBuildingLimitNum=500"; return 0 ;;
    3) echo "MaxBuildingLimitNum=2000"; return 0 ;;
    4) echo "MaxBuildingLimitNum=5000"; return 0 ;;
    5) echo "MaxBuildingLimitNum=10000"; return 0 ;;
    6) echo "MaxBuildingLimitNum=0"; return 0 ;;
    *) echo "MaxBuildingLimitNum=10000"; return 0 ;;
  esac
}

# --- Bases and guild ---
echo ""
echo "=== Bases and guild ==="
OUTPUT="$OUTPUT"$'\n'"$(prompt_int "BaseCampMaxNum" "Maximum number of base camps (performance)." "128" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int_range "BaseCampWorkerMaxNum" "Max work Pals at base." "30" "1" "50" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int_range "BaseCampMaxNumInGuild" "Max bases per guild." "6" "2" "10" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_int_range "GuildPlayerMaxNum" "Maximum guild members." "20" "1" "100" "Integer.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bAutoResetGuildNoOnlinePlayers" "Auto delete guild when no one logs in." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float "AutoResetGuildTimeNoOnlinePlayers" "Hours offline before auto-reset (if above enabled)." "72.000000" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_max_structures)"

# --- Features ---
echo ""
echo "=== Features ==="
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bEnableFastTravel" "Enable fast travel." "True" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bEnableFastTravelOnlyBaseCamp" "Restrict fast travel to bases only." "False" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bIsStartLocationSelectByMap" "Allow choosing start location on map." "True" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bExistPlayerAfterLogout" "Players sleep at logout location (False = delete position)." "False" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bHardcore" "Hardcore mode (no respawn on death)." "False" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bShowPlayerList" "Show player list in ESC menu." "True" "True/False or 1/0.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bAllowGlobalPalboxExport" "Allow Pal genetic data in Global Palbox (save)." "True" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bAllowGlobalPalboxImport" "Allow loading from Global Palbox." "False" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_randomizer_type)"
OUTPUT="$OUTPUT"$'\n'"$(prompt_string "RandomizerSeed" "Seed for Pal randomizer (if enabled)." "" "String or word, e.g. tomato.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_bool "bIsRandomizerPalLevelRandom" "Random mode: wild Pal levels fully random." "False" "On/Off.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float "WorkSpeedRate" "Work speed multiplier." "1.000000" "Float.")"
OUTPUT="$OUTPUT"$'\n'"$(prompt_float_range "ServerReplicatePawnCullDistance" "Pal sync distance from players (5000–15000 cm)." "15000.000000" "5000" "15000" "Float.")"

# Write INI: use [/Script/Pal.PalGameWorldSettings] and OptionSettings= for compatibility
# Build OptionSettings=(Key=Value,...) - strip newlines from OUTPUT and join with comma
OPTIONS=""
first=1
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ $first -eq 1 ]]; then
    OPTIONS="$line"
    first=0
  else
    OPTIONS="$OPTIONS,$line"
  fi
done <<< "$OUTPUT"

{
  echo "[/Script/Pal.PalGameWorldSettings]"
  echo "OptionSettings=($OPTIONS)"
} > "$CONFIG_FILE"

chown steam:steam "$CONFIG_FILE"
echo ""
echo "Config written to $CONFIG_FILE"
echo ""
if [[ -n "${PALWORLD_CONFIG_NO_START:-}" ]]; then
  echo "Skipping start (PALWORLD_CONFIG_NO_START set; caller will start service)."
else
  read -r -p "Start palworld service now? [Y/n]: " start_now
  if [[ "${start_now:-y}" =~ ^[Yy] ]]; then
    systemctl start palworld.service
    echo "Palworld service started."
  else
    echo "Start manually when ready: sudo systemctl start palworld"
  fi
fi
