//
//  ADDrawCellCollectionView.h
//  cell的拖曳
//
//  Created by 王奥东 on 16/7/11.
//  Copyright © 2016年 王奥东. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ADDrawCellCollectionView;

@protocol ADDrawCellCollectionViewDelegate <UICollectionViewDelegate>

@required
//当数据源更新的时候调用，必须实现，需要将新的数据源设置为当前的数据源
//newDataArray 更新后的数据源

-(void)dragCellCollectionView:(ADDrawCellCollectionView *)collectionView newDataArrayAfterMove:(NSArray *)newDataArray;

@optional
//将某个cell将要开始移动的时候调用
//indexPath 该cell当前的indexPath
-(void)dragCellCollectionView:(ADDrawCellCollectionView *)collectionView cellWillBeginMoveAtIndexPath:(NSIndexPath *)indexPath;

//某个Cell正在移动的时候
-(void)dragCellCollectionViewCellisMoing:(ADDrawCellCollectionView *)collectionView;

//cell移动完毕,并成功移动到新位置的时候调用
-(void)dragCellCollectionViewCellEndMoving:(ADDrawCellCollectionView *)collectionView;

//成功交换了位置的时候调用
//fromIndexPath     交换cell的起始位置
//toIndexPath       交换cell的新位置
-(void)dragCellCollectionView:(ADDrawCellCollectionView *)collectionView moveCellFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath;

@end


@protocol ADDragCellCollectionViewDataSource<UICollectionViewDataSource>

@required
//返回整个CollectionView的数据，必须实现，需根据数据进行移动后的数据重排
-(NSArray *)dataSourceArrayOfCollectionView:(ADDrawCellCollectionView *)collectionView;

@end

@interface ADDrawCellCollectionView : UICollectionView

//
//@property (nonatomic, assign) id<XWDragCellCollectionViewDelegate> delegate;
//@property (nonatomic, assign) id<XWDragCellCollectionViewDataSource> dataSource;
//
@property(nonatomic, weak) id<ADDrawCellCollectionViewDelegate> delegate;

@property(nonatomic, weak) id<ADDragCellCollectionViewDataSource> dataSource;
///**长按多少秒触发拖动手势，默认1秒，如果设置为0，表示手指按下去立刻就触发拖动*/
//@property (nonatomic, assign) NSTimeInterval minimumPressDuration;

//长按多少秒触发拖动手势，默认1秒，如果设置为0，表示手指按下去立刻就触发拖动
@property(nonatomic, assign) NSTimeInterval minimumPressDuration;

//是否开启拖动到边缘滚动CollectionView的功能，默认YES
@property(nonatomic,assign) BOOL edgeScrollEable;
//是否开启拖动的时候所有cell抖动的效果,默认YES
@property(nonatomic, assign) BOOL shakeWhenMoveing;

//抖动的等级(1.0f ~ 10.0f),默认4
@property(nonatomic,assign) CGFloat shakeLevel;
//是否正在编辑模式，调用ad_enterEditingModel和ad_stopEditingModel会修改该方法的值
@property(nonatomic,assign,readonly,getter=isEditing) BOOL editing;

//进入编辑模式，如果开启抖动会自动持续抖动，且不用长按就能触发拖动
-(void)ad_enterEditingModel;
//退出编辑模式
-(void)ad_stopEditingModel;























@end
