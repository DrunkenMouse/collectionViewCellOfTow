//
//  ViewController.m
//  cell的拖曳
//
//  Created by 王奥东 on 16/7/8.
//  Copyright © 2016年 王奥东. All rights reserved.
//

#import "ViewController.h"
#import "ADCell.h"
#import "ADCellModel.h"
#import "ADDrawCellCollectionView.h"

@interface ViewController ()<ADDrawCellCollectionViewDelegate,ADDragCellCollectionViewDataSource>
//数据源
@property(nonatomic,strong)NSArray *data;
//显示的View
@property(nonatomic,strong)ADDrawCellCollectionView *mainView;
//编辑按钮
@property(nonatomic,assign)UIBarButtonItem *editButton;

@end

@implementation ViewController

-(NSArray *)data{
    if (!_data) {
        NSMutableArray *temp = @[].mutableCopy;
        NSArray *colors = @[[UIColor redColor],[UIColor blueColor],[UIColor yellowColor],[UIColor orangeColor],[UIColor greenColor]];
        for (int i = 0; i < 5; i++) {
            NSMutableArray *tempSection = @[].mutableCopy;
            //最少有五个，最多有11个
            for (int j = 0; j< arc4random() %6 +5; j++) {
                NSString *str = [NSString stringWithFormat:@"%d -- %d",i,j];
                ADCellModel *model = [ADCellModel new];
                model.backGroundColor = colors[i];
                model.title = str;
                [tempSection addObject:model];
                
            }
            [temp addObject:tempSection.copy];
            
        }
        _data = temp.copy;
    }
    return _data;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //创建并设置添加CollectionView
    self.title = @"ADDragCellCollectionView";
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(80, 80);
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    ADDrawCellCollectionView *mainView = [[ADDrawCellCollectionView alloc]initWithFrame:self.view.bounds collectionViewLayout:layout];
    _mainView = mainView;
    mainView.delegate = self;
    mainView.dataSource = self;
    mainView.shakeLevel = 3.0f;
    mainView.backgroundColor = [UIColor whiteColor];
    [mainView registerClass:[ADCell class] forCellWithReuseIdentifier:@"ADCell"];
    
    [self.view addSubview:mainView];
    
    //创建一个提供编辑功能的BarButton
    UIBarButtonItem *editingButton = [[UIBarButtonItem alloc]initWithTitle:@"编辑" style:UIBarButtonItemStylePlain target:self action:@selector(ad_editing:)];
    _editButton = editingButton;
    self.navigationItem.rightBarButtonItem = editingButton;
    
    
}

-(void)ad_editing:(UIBarButtonItem *)sender{

    if (_mainView.isEditing) {
        [_mainView ad_stopEditingModel];
        sender.title = @"编辑";
    }else{
        [_mainView ad_enterEditingModel];
        sender.title = @"退出";
    }
}

#pragma mark - dataSource代理方法的应用

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return self.data.count;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    NSArray *sec = _data[section];
    return sec.count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    ADCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ADCell" forIndexPath:indexPath];
    
    cell.data = _data[indexPath.section][indexPath.row];
    
    return cell;
}

//以下添加注释的即为自己写的代理方法
//数据源的必须实现，其余三个选择实现
//获取当前collectionView的数据源
-(NSArray *)dataSourceArrayOfCollectionView:(ADDrawCellCollectionView *)collectionView{
    return _data;
}


#pragma mark - delegate代理方法的应用
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    ADCellModel *model = _data[indexPath.section][indexPath.row];
    NSLog(@"点击了%@",model.title);
}

//数据源更新结束后重复赋值给data
-(void)dragCellCollectionView:(ADDrawCellCollectionView *)collectionView newDataArrayAfterMove:(NSArray *)newDataArray{
    _data = newDataArray;
}

//cell开始移动时让代理对象禁用编辑模式
-(void)dragCellCollectionView:(ADDrawCellCollectionView *)collectionView cellWillBeginMoveAtIndexPath:(NSIndexPath *)indexPath{
    //拖动时候禁用编辑按钮的点击
    _editButton.enabled = NO;
}

//cell正在移动时
-(void)dragCellCollectionViewCellisMoing:(ADDrawCellCollectionView *)collectionView{
    
}

//cell移动结束后回复右上角BarButoon的用户交互
-(void)dragCellCollectionViewCellEndMoving:(ADDrawCellCollectionView *)collectionView{
    _editButton.enabled = YES;
}








@end
