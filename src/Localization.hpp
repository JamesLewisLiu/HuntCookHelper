#pragma once
#include "Profiles.hpp"

namespace hc {
enum class MenuLanguage { english, chinese, korean, japanese };
inline int originalLanguageCode = 0;
inline bool japaneseMenu() {
    return activeProfile().core.uuid == sample::japanese.uuid;
}
inline MenuLanguage languageFor(const ExecutableProfile &profile, int code) {
    if (profile.core.uuid == sample::japanese.uuid) return MenuLanguage::japanese;
    if (code == 1 || code == 20) return MenuLanguage::chinese;
    if (code == 8) return MenuLanguage::korean;
    return MenuLanguage::english;
}
inline MenuLanguage menuLanguage() { return languageFor(activeProfile(), originalLanguageCode); }
inline std::size_t catalogNameOffset() {
    if (japaneseMenu()) return 64;
    switch (originalLanguageCode) {
        case 8: return 88;
        case 1: return 112;
        case 20: return 136;
        default: return 64;
    }
}
void refreshMenuLanguage();
}

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
static inline NSString *HCText(NSString *english, NSString *japanese) {
    static NSDictionary<NSString *, NSString *> *chinese;
    static NSDictionary<NSString *, NSString *> *korean;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        chinese = @{
            @"HCHelper Settings": @"HCHelper 设置",
            @"Ignore Traps": @"忽略陷阱",
            @"Freeze Timer": @"冻结计时",
            @"Lucky Cooking": @"料理必定好运",
            @"Guaranteed Recipe": @"必得特殊食谱",
            @"Large Hunt Event": @"大型猎物事件",
            @"Freeze Hunt Points": @"冻结狩猎点",
            @"Guarantee the locked special recipe for the selected hunt map": @"所选地图的特殊食谱未解锁时必定出现",
            @"Guarantee a large prey event when starting a hunt": @"开始狩猎时必定触发大型猎物事件",
            @"Freeze the current hunt point balance": @"固定当前狩猎点数量",
            @"Open Editor": @"打开编辑器",
            @"Editor Unavailable": @"编辑器不可用",
            @"Recipes": @"食谱",
            @"Large Hunt Events": @"大型猎物事件",
            @"Hunt Points": @"狩猎点",
            @"Loaded - Unsupported: %@": @"已加载，不支持：%@",
            @"Loaded - All features available": @"已加载，所有功能可用",
            @"Unsupported Game Version": @"不支持当前游戏版本",
            @"Installation Failed - Restart the Game": @"安装失败，请重启游戏",
            @"Waiting to Load": @"等待加载",
            @"Saved and verified. Reopen the relevant game screen to refresh.": @"已保存并验证。重新打开游戏对应页面即可刷新。",
            @"Data is not loaded. Open the home screen or storehouse, then try again.": @"数据尚未加载。请先打开主页或食物柜，再重试。",
            @"Editor validation failed. This game version is not supported.": @"编辑器验证失败，不支持当前游戏版本。",
            @"Enter a whole number within the allowed range and step.": @"请输入符合允许范围和步长的整数。",
            @"The value changed in the game. Reopen the editor and try again.": @"游戏中的数值已变化。请重新打开编辑器后重试。",
            @"Save or verification failed. Refresh and check the current value.": @"保存或验证失败，请刷新并检查当前数值。",
            @"The original value could not be restored. Refresh and check your save.": @"无法恢复原始数值，请刷新并检查存档。",
            @"Edit failed": @"编辑失败",
            @"Experience (Total)": @"经验值（累计）",
            @"Coins": @"金币",
            @"Diamonds": @"钻石",
            @"Red Cow": @"红乳牛",
            @"Training Tickets": @"训练券",
            @"Storehouse Capacity (Slots)": @"食物柜上限（格数）",
            @"Dishes": @"料理",
            @"Ingredients": @"食材",
            @"Set Owned %@ to 99": @"拥有的%@设为99",
            @"Set All %@ to 99": @"所有%@设为99",
            @"Set Owned %@ to 198": @"拥有的%@设为198",
            @"Set All %@ to 198": @"所有%@设为198",
            @"%@ Quantities": @"%@数量",
            @"Value Editor": @"数值编辑",
            @"Search %@ by name or ID": @"按名称或ID搜索%@",
            @"Close": @"关闭",
            @"Select %@": @"选择%@",
            @"Achievements": @"成就",
            @"Player and Resources": @"玩家与资源",
            @"Tap an item to edit its saved value. Experience edits change the total; levels and unlocks follow the game's normal rules.": @"点击项目可编辑存档数值。经验值修改的是累计总量；升级和解锁遵循游戏原有规则。",
            @"ID %d - Quantity: %d": @"ID %d · 数量：%d",
            @"Achievement Progress": @"成就进度",
            @"View targets and edit completed progress": @"查看目标并编辑已完成次数",
            @"Select an item to edit its quantity": @"选择项目以编辑数量",
            @"Includes %@ with zero quantity. Tap to save immediately.": @"包含数量为0的%@，点击立即保存。",
            @"%@ with zero quantity stay unchanged. Tap to save immediately.": @"数量为0的%@保持不变，点击立即保存。",
            @"Current value: %d": @"当前数值：%d",
            @"Saved and verified %zu %@ types; %zu were unchanged. Reopen the storehouse to refresh.": @"已保存并验证%zu种%@；%zu种未变化。重新打开食物柜即可刷新。",
            @"Batch edit was not applied: an invalid quantity was found. Allowed range: 0-999999.": @"发现无效数量，未执行批量修改。允许范围：0～999999。",
            @"%@\nSaved %zu types; %zu remain unfinished. Verified changes remain saved.": @"%@\n已保存%zu种；%zu种尚未完成。已验证的修改仍保存在存档中。",
            @"OK": @"确定",
            @"Current: %d\nEnter a whole number from %d to %d. Changes are saved to the game.": @"当前：%d\n请输入%d～%d的整数。修改会保存到游戏存档。",
            @"\nWhile frozen, manual edits set the new frozen value. You cannot start a hunt with 0 points.": @"\n冻结期间手动修改会设定新的冻结值。狩猎点为0时无法开始狩猎。",
            @"\nEach page has 12 slots. Enter a multiple of 12, such as 120, 600, or 1200. Reopen the storehouse after saving.": @"\n每页有12格。请输入12的倍数，例如120、600或1200。保存后请重新打开食物柜。",
            @"New quantity": @"新数量",
            @"Cancel": @"取消",
            @"Save": @"保存",
            @"Search achievements by name, condition, or ID": @"按名称、条件或ID搜索成就",
            @"Achievement data is not loaded. Open the game's Achievements screen, then return and refresh.": @"成就数据尚未加载。请先打开游戏成就页面，再返回刷新。",
            @"Tap to edit completed progress. Targets follow the game's rules and share cumulative progress across tiers. Conditions such as total sales use their native units. Claim rewards on the game's Achievements screen.": @"点击可编辑已完成次数。目标遵循游戏规则，各阶段共享累计进度。累计销售额等条件使用游戏原有单位。奖励请在游戏成就页面领取。",
            @"Target: %d - Completed: %d\nTier %zu/%zu - Claimed tiers: %d - ID %d": @"目标：%d · 已完成：%d\n阶段 %zu/%zu · 已领奖阶段：%d · ID %d",
            @"Target: %d\nCompleted: %d\nTier targets: %@\nEdit completed progress (0-%d). Claim rewards on the game's Achievements screen.": @"目标：%d\n已完成：%d\n各阶段目标：%@\n编辑已完成次数（0～%d）。奖励请在游戏成就页面领取。",
            @"Edit Achievement Progress": @"编辑成就进度",
            @"Completed progress": @"已完成次数"
        };
        korean = @{
            @"HCHelper Settings": @"HCHelper 설정",
            @"Ignore Traps": @"함정 무시",
            @"Freeze Timer": @"타이머 고정",
            @"Lucky Cooking": @"요리 행운 보장",
            @"Guaranteed Recipe": @"특수 레시피 보장",
            @"Large Hunt Event": @"대형 사냥감 이벤트",
            @"Freeze Hunt Points": @"사냥 포인트 고정",
            @"Guarantee the locked special recipe for the selected hunt map": @"선택한 사냥 맵의 특수 레시피가 잠겨 있으면 반드시 등장",
            @"Guarantee a large prey event when starting a hunt": @"사냥 시작 시 대형 사냥감 이벤트 보장",
            @"Freeze the current hunt point balance": @"현재 사냥 포인트 고정",
            @"Open Editor": @"편집기 열기",
            @"Editor Unavailable": @"편집기 사용 불가",
            @"Recipes": @"레시피",
            @"Large Hunt Events": @"대형 사냥감 이벤트",
            @"Hunt Points": @"사냥 포인트",
            @"Loaded - Unsupported: %@": @"로드 완료 - 미지원: %@",
            @"Loaded - All features available": @"로드 완료 - 모든 기능 사용 가능",
            @"Unsupported Game Version": @"지원하지 않는 게임 버전",
            @"Installation Failed - Restart the Game": @"설치 실패 - 게임을 다시 시작하세요",
            @"Waiting to Load": @"로드 대기 중",
            @"Saved and verified. Reopen the relevant game screen to refresh.": @"저장 및 확인 완료. 게임의 해당 화면을 다시 열면 갱신됩니다.",
            @"Data is not loaded. Open the home screen or storehouse, then try again.": @"데이터가 로드되지 않았습니다. 홈 화면이나 식료품 창고를 연 후 다시 시도하세요.",
            @"Editor validation failed. This game version is not supported.": @"편집기 검증 실패. 이 게임 버전은 지원하지 않습니다.",
            @"Enter a whole number within the allowed range and step.": @"허용 범위와 단위에 맞는 정수를 입력하세요.",
            @"The value changed in the game. Reopen the editor and try again.": @"게임 내 값이 변경되었습니다. 편집기를 다시 열고 시도하세요.",
            @"Save or verification failed. Refresh and check the current value.": @"저장 또는 확인 실패. 새로 고침 후 현재 값을 확인하세요.",
            @"The original value could not be restored. Refresh and check your save.": @"원래 값을 복원하지 못했습니다. 새로 고침 후 저장 데이터를 확인하세요.",
            @"Edit failed": @"편집 실패",
            @"Experience (Total)": @"경험치 (누적)",
            @"Coins": @"코인",
            @"Diamonds": @"다이아",
            @"Red Cow": @"레드 카우",
            @"Training Tickets": @"훈련 티켓",
            @"Storehouse Capacity (Slots)": @"식료품 창고 용량 (칸)",
            @"Dishes": @"요리",
            @"Ingredients": @"재료",
            @"Set Owned %@ to 99": @"보유한 %@ 수량을 99로 설정",
            @"Set All %@ to 99": @"모든 %@ 수량을 99로 설정",
            @"Set Owned %@ to 198": @"보유한 %@ 수량을 198로 설정",
            @"Set All %@ to 198": @"모든 %@ 수량을 198로 설정",
            @"%@ Quantities": @"%@ 수량",
            @"Value Editor": @"값 편집",
            @"Search %@ by name or ID": @"이름 또는 ID로 %@ 검색",
            @"Close": @"닫기",
            @"Select %@": @"%@ 선택",
            @"Achievements": @"업적",
            @"Player and Resources": @"플레이어 및 자원",
            @"Tap an item to edit its saved value. Experience edits change the total; levels and unlocks follow the game's normal rules.": @"항목을 눌러 저장된 값을 편집하세요. 경험치는 누적값을 변경하며 레벨과 해금은 게임의 기존 규칙을 따릅니다.",
            @"ID %d - Quantity: %d": @"ID %d - 수량: %d",
            @"Achievement Progress": @"업적 진행도",
            @"View targets and edit completed progress": @"목표 확인 및 완료 진행도 편집",
            @"Select an item to edit its quantity": @"항목을 선택하여 수량 편집",
            @"Includes %@ with zero quantity. Tap to save immediately.": @"수량이 0인 %@도 포함됩니다. 누르면 즉시 저장됩니다.",
            @"%@ with zero quantity stay unchanged. Tap to save immediately.": @"수량이 0인 %@는 변경하지 않습니다. 누르면 즉시 저장됩니다.",
            @"Current value: %d": @"현재 값: %d",
            @"Saved and verified %zu %@ types; %zu were unchanged. Reopen the storehouse to refresh.": @"%zu종의 %@ 저장 및 확인 완료. %zu종은 변경 없음. 식료품 창고를 다시 열면 갱신됩니다.",
            @"Batch edit was not applied: an invalid quantity was found. Allowed range: 0-999999.": @"잘못된 수량이 발견되어 일괄 편집하지 않았습니다. 허용 범위: 0~999999.",
            @"%@\nSaved %zu types; %zu remain unfinished. Verified changes remain saved.": @"%@\n%zu종 저장됨. %zu종은 미완료. 확인된 변경은 저장되어 있습니다.",
            @"OK": @"확인",
            @"Current: %d\nEnter a whole number from %d to %d. Changes are saved to the game.": @"현재: %d\n%d~%d 범위의 정수를 입력하세요. 변경은 게임에 저장됩니다.",
            @"\nWhile frozen, manual edits set the new frozen value. You cannot start a hunt with 0 points.": @"\n고정 중 수동 편집 시 새 값으로 고정됩니다. 0포인트로는 사냥을 시작할 수 없습니다.",
            @"\nEach page has 12 slots. Enter a multiple of 12, such as 120, 600, or 1200. Reopen the storehouse after saving.": @"\n페이지당 12칸입니다. 120, 600, 1200처럼 12의 배수를 입력하세요. 저장 후 식료품 창고를 다시 여세요.",
            @"New quantity": @"새 수량",
            @"Cancel": @"취소",
            @"Save": @"저장",
            @"Search achievements by name, condition, or ID": @"이름, 조건 또는 ID로 업적 검색",
            @"Achievement data is not loaded. Open the game's Achievements screen, then return and refresh.": @"업적 데이터가 로드되지 않았습니다. 게임의 업적 화면을 연 후 돌아와 새로 고침하세요.",
            @"Tap to edit completed progress. Targets follow the game's rules and share cumulative progress across tiers. Conditions such as total sales use their native units. Claim rewards on the game's Achievements screen.": @"눌러 완료 진행도를 편집하세요. 목표는 게임 규칙을 따르며 단계 간 누적 진행도를 공유합니다. 총 매출 등의 조건은 기존 단위를 사용합니다. 보상은 게임의 업적 화면에서 받으세요.",
            @"Target: %d - Completed: %d\nTier %zu/%zu - Claimed tiers: %d - ID %d": @"목표: %d - 완료: %d\n단계 %zu/%zu - 보상 수령 단계: %d - ID %d",
            @"Target: %d\nCompleted: %d\nTier targets: %@\nEdit completed progress (0-%d). Claim rewards on the game's Achievements screen.": @"목표: %d\n완료: %d\n단계별 목표: %@\n완료 진행도 편집 (0~%d). 보상은 게임의 업적 화면에서 받으세요.",
            @"Edit Achievement Progress": @"업적 진행도 편집",
            @"Completed progress": @"완료 진행도"
        };
    });
    switch (hc::menuLanguage()) {
        case hc::MenuLanguage::japanese: return japanese;
        case hc::MenuLanguage::chinese: return chinese[english] ?: english;
        case hc::MenuLanguage::korean: return korean[english] ?: english;
        default: return english;
    }
}
#endif
