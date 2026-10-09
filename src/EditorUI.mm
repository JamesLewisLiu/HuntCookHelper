#import <UIKit/UIKit.h>
#include "Localization.hpp"
#include "Editor.hpp"
#include "EditorUI.hpp"
#include "Achievement.hpp"
#include <algorithm>

static NSString *HCEditMessage(hc::EditResult result) {
    switch (result) {
        case hc::EditResult::ok: return HCText(@"Saved and verified. Reopen the relevant game screen to refresh.", @"保存と確認が完了しました。ゲームの該当画面を開き直すと表示が更新されます。");
        case hc::EditResult::unavailable: return HCText(@"Data is not loaded. Open the home screen or storehouse, then try again.", @"データが未読み込みです。ホーム画面または食料庫を開いてから、もう一度お試しください。");
        case hc::EditResult::unsupported: return HCText(@"Editor validation failed. This game version is not supported.", @"編集機能の検証に失敗しました。このゲームバージョンには対応していません。");
        case hc::EditResult::invalidInput: return HCText(@"Enter a whole number within the allowed range and step.", @"指定された範囲と単位に合う整数を入力してください。");
        case hc::EditResult::changed: return HCText(@"The value changed in the game. Reopen the editor and try again.", @"ゲーム内で値が変更されました。編集画面を開き直して、もう一度お試しください。");
        case hc::EditResult::writeFailed: return HCText(@"Save or verification failed. Refresh and check the current value.", @"保存または確認に失敗しました。更新して現在の値を確認してください。");
        case hc::EditResult::rollbackFailed: return HCText(@"The original value could not be restored. Refresh and check your save.", @"元の値に戻せませんでした。更新してセーブデータを確認してください。");
    }
    return HCText(@"Edit failed", @"編集に失敗しました");
}
static NSString *HCResourceName(hc::Resource resource) {
    switch (resource) {
        case hc::Resource::experience: return HCText(@"Experience (Total)", @"経験値（累計）");
        case hc::Resource::coin: return HCText(@"Coins", @"コイン");
        case hc::Resource::diamond: return HCText(@"Diamonds", @"ダイヤ");
        case hc::Resource::redCow: return HCText(@"Red Cow", @"レッドカウ");
        case hc::Resource::trainingTicket: return HCText(@"Training Tickets", @"トレーニングチケット");
        case hc::Resource::huntPoints: return HCText(@"Hunt Points", @"狩猟ポイント");
        case hc::Resource::storehouseCapacity: return HCText(@"Storehouse Capacity (Slots)", @"食料庫の上限（枠数）");
    }
    return @"";
}
static constexpr hc::Resource HCResources[] = {hc::Resource::experience, hc::Resource::coin,
    hc::Resource::diamond, hc::Resource::redCow, hc::Resource::trainingTicket, hc::Resource::huntPoints,
    hc::Resource::storehouseCapacity};
static NSString *HCInventoryName(hc::InventoryKind kind) {
    return kind == hc::InventoryKind::dishes ? HCText(@"Dishes", @"料理") : HCText(@"Ingredients", @"食材");
}
static hc::InventoryKind HCInventoryForSection(NSInteger section) {
    return section == 2 ? hc::InventoryKind::dishes : hc::InventoryKind::ingredients;
}
static constexpr hc::FoodBatchOperation HCBatchOperations[] = {hc::FoodBatchOperation::setOwned99,
    hc::FoodBatchOperation::setAll99, hc::FoodBatchOperation::setOwned198, hc::FoodBatchOperation::setAll198};
static NSString *HCFoodBatchTitle(NSInteger row, hc::InventoryKind kind) {
    NSString *name = HCInventoryName(kind);
    switch (row) {
        case 1: return [NSString stringWithFormat:HCText(@"Set Owned %@ to 99", @"所持している%@を99に設定"), name];
        case 2: return [NSString stringWithFormat:HCText(@"Set All %@ to 99", @"すべての%@を99に設定"), name];
        case 3: return [NSString stringWithFormat:HCText(@"Set Owned %@ to 198", @"所持している%@を198に設定"), name];
        default: return [NSString stringWithFormat:HCText(@"Set All %@ to 198", @"すべての%@を198に設定"), name];
    }
}

@interface HCAchievementController : UITableViewController <UISearchResultsUpdating> {
    std::vector<hc::AchievementEntry> _achievements;
    std::vector<hc::AchievementEntry> _filtered;
}
@property(nonatomic, strong) UISearchController *search;
@property(nonatomic, copy) NSString *notice;
@property(nonatomic) BOOL loadFailed;
@property(nonatomic, weak) UITextField *quantityField;
@property(nonatomic, weak) UIAlertAction *saveAction;
@end

@interface HCEditorController : UITableViewController <UISearchResultsUpdating> {
    std::vector<hc::FoodEntry> _foods;
    std::vector<hc::FoodEntry> _filteredFoods;
}
@property(nonatomic) BOOL foodMode;
@property(nonatomic) hc::InventoryKind inventoryKind;
@property(nonatomic, copy) NSString *notice;
@property(nonatomic, strong) UISearchController *foodSearch;
@property(nonatomic, weak) UIWindow *previousKeyWindow;
@property(nonatomic, weak) UITextField *quantityField;
@property(nonatomic, weak) UIAlertAction *saveAction;
@property(nonatomic) int quantityMaximum;
@property(nonatomic) int quantityMinimum;
@property(nonatomic) int quantityStep;
@end

@implementation HCEditorController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70;
    self.title = self.foodMode ? [NSString stringWithFormat:HCText(@"%@ Quantities", @"%@の数量"), HCInventoryName(self.inventoryKind)] : HCText(@"Value Editor", @"値の編集");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self action:@selector(reloadValues)];
    if (self.foodMode) {
        self.foodSearch = [[UISearchController alloc] initWithSearchResultsController:nil];
        self.foodSearch.searchResultsUpdater = self;
        self.foodSearch.obscuresBackgroundDuringPresentation = NO;
        self.foodSearch.searchBar.placeholder = [NSString stringWithFormat:HCText(@"Search %@ by name or ID", @"%@を名前またはIDで検索"), HCInventoryName(self.inventoryKind)];
        self.navigationItem.searchController = self.foodSearch;
        self.definesPresentationContext = YES;
    } else {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:HCText(@"Close", @"閉じる")
            style:UIBarButtonItemStylePlain target:self action:@selector(closeEditor)];
    }
    [self reloadValues];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadValues];
}
- (void)closeEditor {
    [self.view endEditing:YES];
    UIWindow *previous = self.previousKeyWindow;
    [self dismissViewControllerAnimated:YES completion:^{
        if (previous && !previous.hidden) [previous makeKeyWindow];
    }];
}
- (void)reloadValues {
    hc::refreshMenuLanguage();
    self.title = self.foodMode ? [NSString stringWithFormat:HCText(@"%@ Quantities", @"%@の数量"), HCInventoryName(self.inventoryKind)] : HCText(@"Value Editor", @"値の編集");
    if (self.foodMode)
        self.foodSearch.searchBar.placeholder = [NSString stringWithFormat:HCText(@"Search %@ by name or ID", @"%@を名前またはIDで検索"), HCInventoryName(self.inventoryKind)];
    else self.navigationItem.leftBarButtonItem.title = HCText(@"Close", @"閉じる");
    if (self.foodMode) {
        const auto result = hc::listFoods(_foods, self.inventoryKind);
        if (result != hc::EditResult::ok) self.notice = HCEditMessage(result);
        [self filterFoods];
    }
    [self.tableView reloadData];
}
- (void)filterFoods {
    _filteredFoods.clear();
    NSString *query = self.foodSearch.searchBar.text ?: @"";
    for (const auto &food : _foods) {
        NSString *name = [NSString stringWithUTF8String:food.name.c_str()] ?: @"";
        NSString *identifier = [NSString stringWithFormat:@"%d", food.id];
        if (!query.length || [name localizedCaseInsensitiveContainsString:query] || [identifier containsString:query])
            _filteredFoods.push_back(food);
    }
}
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
    (void)controller;
    [self filterFoods];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return self.foodMode ? 1 : 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (self.foodMode) return static_cast<NSInteger>(_filteredFoods.size());
    if (section == 0) return sizeof(HCResources) / sizeof(HCResources[0]);
    return section == 3 ? 1 : 5;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (self.foodMode) return [NSString stringWithFormat:HCText(@"Select %@", @"%@を選択"), HCInventoryName(self.inventoryKind)];
    if (section == 3) return HCText(@"Achievements", @"実績");
    return section == 0 ? HCText(@"Player and Resources", @"プレイヤーと所持品") : HCInventoryName(HCInventoryForSection(section));
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section != 0) return nil;
    return self.notice ?: HCText(@"Tap an item to edit its saved value. Experience edits change the total; levels and unlocks follow the game's normal rules.", @"項目をタップすると保存された値を編集できます。経験値は累計を変更します。レベルや解禁はゲーム本来のルールに従います。");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"edit"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"edit"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    if (self.foodMode) {
        const auto &food = _filteredFoods.at(static_cast<std::size_t>(path.row));
        NSString *name = [NSString stringWithUTF8String:food.name.c_str()];
        cell.textLabel.text = name.length ? name : [NSString stringWithFormat:@"%@ %d", HCInventoryName(self.inventoryKind), food.id];
        cell.detailTextLabel.text = [NSString stringWithFormat:HCText(@"ID %d - Quantity: %d", @"ID %d・数量：%d"), food.id, food.quantity];
    } else if (path.section == 3) {
        cell.textLabel.text = HCText(@"Achievement Progress", @"実績の進捗");
        cell.detailTextLabel.text = HCText(@"View targets and edit completed progress", @"目標を確認し、達成済みの回数を編集");
    } else if (path.section > 0) {
        const auto kind = HCInventoryForSection(path.section);
        NSString *name = HCInventoryName(kind);
        if (path.row == 0) {
            cell.textLabel.text = [NSString stringWithFormat:HCText(@"%@ Quantities", @"%@の数量"), name];
            cell.detailTextLabel.text = HCText(@"Select an item to edit its quantity", @"項目を選択して数量を編集");
        } else {
            cell.textLabel.text = HCFoodBatchTitle(path.row, kind);
            cell.detailTextLabel.text = path.row == 2 || path.row == 4
                ? [NSString stringWithFormat:HCText(@"Includes %@ with zero quantity. Tap to save immediately.", @"数量が0の%@も対象です。タップするとすぐに保存します。"), name]
                : [NSString stringWithFormat:HCText(@"%@ with zero quantity stay unchanged. Tap to save immediately.", @"数量が0の%@は変更しません。タップするとすぐに保存します。"), name];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = self.view.tintColor;
        }
    } else {
        const auto resource = HCResources[path.row];
        std::int32_t value = 0;
        const auto result = hc::readResource(resource, value);
        cell.textLabel.text = HCResourceName(resource);
        cell.detailTextLabel.text = result == hc::EditResult::ok ? [NSString stringWithFormat:HCText(@"Current value: %d", @"現在の値：%d"), value] : HCEditMessage(result);
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (!self.foodMode && path.section == 3) {
        HCAchievementController *achievements = [[HCAchievementController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        [self.navigationController pushViewController:achievements animated:YES];
        return;
    }
    if (!self.foodMode && path.section > 0) {
        const auto kind = HCInventoryForSection(path.section);
        NSString *name = HCInventoryName(kind);
        if (path.row > 0) {
            const auto operation = HCBatchOperations[path.row - 1];
            const auto saved = hc::editFoods(operation, kind);
            NSString *message;
            if (saved.result == hc::EditResult::ok) {
                message = [NSString stringWithFormat:HCText(@"Saved and verified %zu %@ types; %zu were unchanged. Reopen the storehouse to refresh.", @"%zu種類の%@を保存・確認しました。%zu種類は変更なしです。食料庫を開き直すと表示が更新されます。"),
                    saved.updated, name, saved.unchanged];
            } else if (saved.result == hc::EditResult::invalidInput) {
                message = HCText(@"Batch edit was not applied: an invalid quantity was found. Allowed range: 0-999999.", @"無効な数量が見つかったため一括編集しませんでした。有効範囲：0～999999。");
            } else if (!saved.updated && !saved.remaining) {
                message = HCEditMessage(saved.result);
            } else {
                message = [NSString stringWithFormat:HCText(@"%@\nSaved %zu types; %zu remain unfinished. Verified changes remain saved.", @"%@\n%zu種類を保存しました。%zu種類は未完了です。確認済みの変更は保存されています。"),
                    HCEditMessage(saved.result), saved.updated, saved.remaining];
            }
            self.notice = message;
            [self reloadValues];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:HCFoodBatchTitle(path.row, kind)
                message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:HCText(@"OK", @"確認") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        HCEditorController *foods = [[HCEditorController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        foods.foodMode = YES;
        foods.inventoryKind = kind;
        [self.navigationController pushViewController:foods animated:YES];
        return;
    }
    const BOOL isFood = self.foodMode;
    const auto kind = self.inventoryKind;
    const auto resource = isFood ? hc::Resource::experience : HCResources[path.row];
    std::int32_t identifier = 0, current = 0;
    NSString *name = HCResourceName(resource);
    hc::EditResult result;
    if (isFood) {
        const auto &food = _filteredFoods.at(static_cast<std::size_t>(path.row));
        identifier = food.id;
        name = [NSString stringWithUTF8String:food.name.c_str()];
        if (!name.length) name = [NSString stringWithFormat:@"%@ %d", HCInventoryName(kind), identifier];
        result = hc::readFood(identifier, current, kind);
    } else result = hc::readResource(resource, current);
    if (result != hc::EditResult::ok) {
        self.notice = HCEditMessage(result);
        [self reloadValues];
        return;
    }
    self.quantityMaximum = isFood ? hc::foodMaximum : hc::resourceLimit(resource);
    self.quantityMinimum = isFood ? 0 : hc::resourceMinimum(resource);
    self.quantityStep = isFood ? 1 : hc::resourceStep(resource);
    NSString *message = [NSString stringWithFormat:HCText(@"Current: %d\nEnter a whole number from %d to %d. Changes are saved to the game.", @"現在：%d\n%d～%dの整数を入力してください。変更はゲームに保存されます。"), current, self.quantityMinimum, self.quantityMaximum];
    if (!isFood && resource == hc::Resource::huntPoints)
        message = [message stringByAppendingString:HCText(@"\nWhile frozen, manual edits set the new frozen value. You cannot start a hunt with 0 points.", @"\n固定中に手動で編集すると、新しい値で固定されます。0ポイントでは狩猟を開始できません。")];
    if (!isFood && resource == hc::Resource::storehouseCapacity)
        message = [message stringByAppendingString:HCText(@"\nEach page has 12 slots. Enter a multiple of 12, such as 120, 600, or 1200. Reopen the storehouse after saving.", @"\n1ページは12枠です。120、600、1200など12の倍数を入力してください。保存後に食料庫を開き直してください。")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.text = [NSString stringWithFormat:@"%d", current];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.accessibilityLabel = HCText(@"New quantity", @"変更後の数量");
        [field addTarget:self action:@selector(quantityChanged:) forControlEvents:UIControlEventEditingChanged];
        self.quantityField = field;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:HCText(@"Cancel", @"キャンセル") style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *save = [UIAlertAction actionWithTitle:HCText(@"Save", @"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        std::int32_t value = 0;
        if (!hc::parseQuantity(self.quantityField.text.UTF8String, self.quantityMaximum, value) ||
            value < self.quantityMinimum || value % self.quantityStep != 0) {
            self.notice = HCEditMessage(hc::EditResult::invalidInput);
        } else {
            const auto saved = isFood ? hc::editFood(identifier, value, current, kind) : hc::editResource(resource, value, current);
            self.notice = HCEditMessage(saved);
        }
        [self reloadValues];
    }];
    [alert addAction:save];
    self.saveAction = save;
    [self quantityChanged:self.quantityField];
    UIViewController *presenter = self;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    [presenter presentViewController:alert animated:YES completion:nil];
}
- (void)quantityChanged:(UITextField *)field {
    std::int32_t parsed = 0;
    self.saveAction.enabled = hc::parseQuantity(field.text.UTF8String, self.quantityMaximum, parsed) &&
        parsed >= self.quantityMinimum && parsed % self.quantityStep == 0;
}
@end

@implementation HCAchievementController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = HCText(@"Achievement Progress", @"実績の進捗");
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 90;
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = HCText(@"Search achievements by name, condition, or ID", @"実績を名前・条件・IDで検索");
    self.navigationItem.searchController = self.search;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self action:@selector(reloadValues)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadValues];
}
- (void)reloadValues {
    hc::refreshMenuLanguage();
    self.title = HCText(@"Achievement Progress", @"実績の進捗");
    self.search.searchBar.placeholder = HCText(@"Search achievements by name, condition, or ID", @"実績を名前・条件・IDで検索");
    const auto result = hc::listAchievements(_achievements);
    if (result == hc::EditResult::ok && self.loadFailed) self.notice = nil;
    self.loadFailed = result != hc::EditResult::ok;
    if (result != hc::EditResult::ok) self.notice = result == hc::EditResult::unavailable
        ? HCText(@"Achievement data is not loaded. Open the game's Achievements screen, then return and refresh.", @"実績データが未読み込みです。ゲームの実績画面を開いてから戻り、更新してください。") : HCEditMessage(result);
    [self filterAchievements];
    [self.tableView reloadData];
}
- (void)filterAchievements {
    _filtered.clear();
    NSString *query = self.search.searchBar.text ?: @"";
    for (const auto &entry : _achievements) {
        NSString *name = [NSString stringWithUTF8String:entry.name.c_str()] ?: @"";
        NSString *key = [NSString stringWithUTF8String:entry.key.c_str()] ?: @"";
        NSString *identifier = [NSString stringWithFormat:@"%d", entry.id];
        if (!query.length || [name localizedCaseInsensitiveContainsString:query] ||
            [key localizedCaseInsensitiveContainsString:query] || [identifier containsString:query]) _filtered.push_back(entry);
    }
}
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
    (void)controller;
    [self filterAchievements];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return static_cast<NSInteger>(_filtered.size());
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.notice ?: HCText(@"Tap to edit completed progress. Targets follow the game's rules and share cumulative progress across tiers. Conditions such as total sales use their native units. Claim rewards on the game's Achievements screen.", @"タップして達成済みの回数を編集できます。目標はゲームのルールに従い、各段階で累計の進捗を共有します。売上合計などの条件は本来の単位を使用します。報酬はゲームの実績画面で受け取ってください。");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"achievement"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"achievement"];
    const auto &entry = _filtered.at(static_cast<std::size_t>(path.row));
    NSString *name = [NSString stringWithUTF8String:entry.name.c_str()];
    cell.textLabel.text = name.length ? name : [NSString stringWithUTF8String:entry.key.c_str()];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.text = [NSString stringWithFormat:HCText(@"Target: %d - Completed: %d\nTier %zu/%zu - Claimed tiers: %d - ID %d", @"目標：%d・達成済み：%d\n段階 %zu/%zu・受取済み：%d・ID %d"),
        entry.targets.at(entry.targetIndex), entry.current, entry.targetIndex + 1, entry.targets.size(), entry.claimed, entry.id];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    const auto identifier = _filtered.at(static_cast<std::size_t>(path.row)).id;
    hc::AchievementEntry entry;
    const auto result = hc::readAchievement(identifier, entry);
    if (result != hc::EditResult::ok) {
        self.notice = HCEditMessage(result); [self reloadValues]; return;
    }
    NSMutableArray<NSString *> *targets = [NSMutableArray array];
    for (const auto target : entry.targets) [targets addObject:[NSString stringWithFormat:@"%d", target]];
    NSString *message = [NSString stringWithFormat:HCText(@"Target: %d\nCompleted: %d\nTier targets: %@\nEdit completed progress (0-%d). Claim rewards on the game's Achievements screen.", @"目標：%d\n達成済み：%d\n各段階の目標：%@\n達成済みの回数を編集（0～%d）。報酬はゲームの実績画面で受け取ってください。"),
        entry.targets.at(entry.targetIndex), entry.current, [targets componentsJoinedByString:@" / "], hc::achievementMaximum];
    NSString *name = [NSString stringWithUTF8String:entry.name.c_str()];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name.length ? name : HCText(@"Edit Achievement Progress", @"実績の進捗を編集")
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.text = [NSString stringWithFormat:@"%d", entry.current];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.accessibilityLabel = HCText(@"Completed progress", @"達成済みの回数");
        [field addTarget:self action:@selector(quantityChanged:) forControlEvents:UIControlEventEditingChanged];
        self.quantityField = field;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:HCText(@"Cancel", @"キャンセル") style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *save = [UIAlertAction actionWithTitle:HCText(@"Save", @"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        std::int32_t value = 0;
        const auto saved = hc::parseQuantity(self.quantityField.text.UTF8String, hc::achievementMaximum, value)
            ? hc::editAchievement(entry.id, entry.key, value, entry.current) : hc::EditResult::invalidInput;
        self.notice = HCEditMessage(saved);
        [self reloadValues];
    }];
    [alert addAction:save];
    self.saveAction = save;
    [self quantityChanged:self.quantityField];
    UIViewController *presenter = self;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    [presenter presentViewController:alert animated:YES completion:nil];
}
- (void)quantityChanged:(UITextField *)field {
    std::int32_t value = 0;
    self.saveAction.enabled = hc::parseQuantity(field.text.UTF8String, hc::achievementMaximum, value);
}
@end

void HCPresentEditor(UIViewController *host) {
    if (host.presentedViewController) return;
    HCEditorController *editor = [[HCEditorController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    for (UIWindow *window in host.view.window.windowScene.windows) {
        if (window.isKeyWindow && window != host.view.window) editor.previousKeyWindow = window;
    }
    if (!editor.previousKeyWindow) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow && window != host.view.window) editor.previousKeyWindow = window;
        }
#pragma clang diagnostic pop
    }
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [host.view.window makeKeyWindow];
    [host presentViewController:navigation animated:YES completion:nil];
}
