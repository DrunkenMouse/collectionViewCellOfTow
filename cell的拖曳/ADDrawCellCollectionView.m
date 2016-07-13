//
//  ADDrawCellCollectionView.m
//  cell的拖曳
//
//  Created by 王奥东 on 16/7/11.
//  Copyright © 2016年 王奥东. All rights reserved.
//



#import "ADDrawCellCollectionView.h"
#import <AudioToolbox/AudioToolbox.h>

#define angelToRandian(x) ((x)/180.0*M_PI)

typedef NS_ENUM(NSUInteger, ADDragCellCollectionViewScrollDirection) {

    ADDrawCellCollectionViewScrollDirectionNone = 0,
    ADDrawCellCollectionViewScrollDirectionLeft,
    ADDrawCellCollectionViewScrollDirectionRight,
    ADDrawCellCollectionViewScrollDirectionUp,
    ADDrawCellCollectionViewScrollDirectionDown
    
};

@interface ADDrawCellCollectionView()
//手机拖动的indexPath
@property(nonatomic,strong)NSIndexPath *originalIndexPath;
//用来交换的indexPath
@property(nonatomic,strong)NSIndexPath *moveIndexPath;
//移动时显示的view
@property(nonatomic,weak)UIView *tempMoveCell;
//手势
@property(nonatomic,weak)UILongPressGestureRecognizer *longPressGesture;
//边缘抖动中的计时器
@property(nonatomic,strong)CADisplayLink *edgeTimer;
//最后一次触摸的坐标点
@property(nonatomic,assign)CGPoint lastPoint;
//枚举值
@property(nonatomic,assign)ADDragCellCollectionViewScrollDirection scrollDirection;
//保存手势长按响应的最小时间的值,在抖动状态时会对手势响应的最小时间进行改变
@property(nonatomic,assign)CGFloat oldMinimumPressDuration;
//判断contentOffset是否被重复监听或移除
//被监听时赋值为YES代表已经监听
//移除时赋值为NO代表已经移除
@property(nonatomic,assign,getter=isObservering) BOOL observering;


@end

@implementation ADDrawCellCollectionView

@dynamic delegate;
@dynamic dataSource;

-(void)dealloc{
    [self removeObserver:self forKeyPath:@"contentOffset"];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}


#pragma mark - 保证初始化时都会调用自己的方法
-(instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(nonnull UICollectionViewLayout *)layout{
    
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self) {
        [self ad_initializeProperty];
        [self ad_addGesture];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)coder{
    self = [super initWithCoder:coder];
    if (self) {
        [self ad_initializeProperty];
        [self ad_addGesture];
    }
    return self;
}

#pragma mark - 对属性的初始化
-(void)ad_initializeProperty{
    _minimumPressDuration = 1;
    _edgeScrollEable = YES;
    _shakeWhenMoveing = YES;
    _shakeLevel = 4.0f;
}

#pragma mark - 添加自定义的手势
-(void)ad_addGesture{
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(ad_longPressed:)];
    _longPressGesture = longPress;
    longPress.minimumPressDuration = _minimumPressDuration;
    [self addGestureRecognizer:longPress];
    
}

#pragma mark - 监听手势的改变
-(void)ad_longPressed:(UILongPressGestureRecognizer *)longPressGesture{
    
    if (longPressGesture.state == UIGestureRecognizerStateBegan) {
        [self ad_gestureBegan:longPressGesture];
    }else if (longPressGesture.state == UIGestureRecognizerStateChanged){
        [self ad_gestureChange:longPressGesture];
    }else if (longPressGesture.state == UIGestureRecognizerStateEnded || longPressGesture.state == UIGestureRecognizerStateCancelled){
        [self ad_gestureEndOrCancel:longPressGesture];
    }
    
}

#pragma mark - 手势开始
//只有当手势开始的时候才会启动边缘滚动检测
//手势开始会先通过重写的hitTest事件判断手势触发的点是否在自身的item上
//如果在就允许手势触发(enabled = YES)
-(void)ad_gestureBegan:(UILongPressGestureRecognizer *)longPressGesture{
 
    //获取手指所在的cell
    //通过相对于手势所触碰到的控件的坐标点，得到我们所触控的是collectionView的哪一组的哪一行
    _originalIndexPath = [self indexPathForItemAtPoint:[longPressGesture locationOfTouch:0 inView:longPressGesture.view]];
    //获取cell
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:_originalIndexPath];
    //截图大法好，通过截图获取cell上的view显示
    UIView *tempMoveCell = [cell snapshotViewAfterScreenUpdates:NO];
    //隐藏cell
    cell.hidden = YES;
    //保存并显示当前拖曳的cell的显示内容
    _tempMoveCell = tempMoveCell;
    _tempMoveCell.frame = cell.frame;
    [self addSubview:_tempMoveCell];
    
    //开启边缘滚动定时器，让所有的Cell不停的改变抖动的方向与x,y
    [self ad_setEdgeTimer];
    
    //开启抖动
    //如果允许抖动并且不在编辑模式
    if (_shakeWhenMoveing && !_editing) {
        [self ad_shakeAllCell];
        //注册一个监听事件，通过displayLink不断地改变监听值然后不断地抖动
        [self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    }
    //保存相对控件的触碰点
    _lastPoint = [longPressGesture locationOfTouch:0 inView:longPressGesture.view];
    
    //通知代理cell将要移动
    if ([self.delegate respondsToSelector:@selector(dragCellCollectionView:cellWillBeginMoveAtIndexPath:)]) {
        [self.delegate dragCellCollectionView:self cellWillBeginMoveAtIndexPath:_originalIndexPath];
    }
    
}

#pragma mark - 手势拖动，做出一些处理并调用cell移动方法进行一些判断
-(void)ad_gestureChange:(UILongPressGestureRecognizer *)longPressGesture{

    
    //通知代理cell正在移动
    if ([self.delegate respondsToSelector:@selector(dragCellCollectionViewCellisMoing:)]) {
        [self.delegate dragCellCollectionViewCellisMoing:self];
    }
    //获取相对于控件来说的偏移的X，Y值
    CGFloat tranX = [longPressGesture locationOfTouch:0 inView:longPressGesture.view].x - _lastPoint.x;
    CGFloat tranY = [longPressGesture locationOfTouch:0 inView:longPressGesture.view].y - _lastPoint.y;
    //通过重定义cell的center来移动cell
    _tempMoveCell.center = CGPointApplyAffineTransform(_tempMoveCell.center, CGAffineTransformMakeTranslation(tranX, tranY));
    //更新已保存的触摸的最后坐标点
    _lastPoint = [longPressGesture locationOfTouch:0 inView:longPressGesture.view];
    //调用cell移动方法,在此方法里判断cell的滚动与位置是否更换
    [self ad_moveCell];
    
}

#pragma mark - 手势结束或取消
-(void)ad_gestureEndOrCancel:(UILongPressGestureRecognizer *)longPressGesture{
    
    //获取最初要开始移动的那个cell
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:_originalIndexPath];
    self.userInteractionEnabled = NO;
    [self ad_stopEdgeTimer];
    //通知代理
    if ([self.delegate respondsToSelector:@selector(dragCellCollectionViewCellEndMoving:)]) {
        [self.delegate dragCellCollectionViewCellEndMoving:self];
    }
    [UIView animateWithDuration:0.25 animations:^{
        //显示的View的中心便就是Cell的中心
        _tempMoveCell.center = cell.center;
    } completion:^(BOOL finished) {
        //移动结束后停止震动，将临时用来展示cell的view移除
        [self ad_stopShakeAllCell];
        [_tempMoveCell removeFromSuperview];
        //cell显示
        cell.hidden = NO;
        //移动时禁止用户交互，移动结束后开启交互
        self.userInteractionEnabled = YES;
        
    }];
    
}

#pragma mark - 当参数被修改时
//当最小响应时间被修改时保存修改的值，并设置手势的最小响应时间
-(void)setMinimumPressDuration:(NSTimeInterval)minimumPressDuration{
    _minimumPressDuration = minimumPressDuration;
    _longPressGesture.minimumPressDuration = minimumPressDuration;
}
//当抖动被修改后，如果小于1.0f就为1.0f，如果大于10.0f就为10.0f
-(void)setShakeLevel:(CGFloat)shakeLevel{
    CGFloat level = MAX(1.0f, shakeLevel);
    _shakeLevel = MIN(level, 10.0f);
}

#pragma mark - 开启边缘滚动定时器,所有cell开始滚动并添加到runLoop
-(void)ad_setEdgeTimer{
    //如果cell滚动并且滚动计时器没有创建就去创建
    if (!_edgeTimer && _edgeScrollEable) {
        _edgeTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(ad_edgeScroll)];
        [_edgeTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}


#pragma mark - 关闭边缘滚动定时器
-(void)ad_stopEdgeTimer{
    
    if (_edgeTimer) {
        [_edgeTimer invalidate];
        _edgeTimer = nil;
    }
}


#pragma mark - 边缘滚动
//边缘滚动用于cell移动到边缘时，让collectionView开始滚动
//此方法里只适用于向下滚动
//而我一开始误以为是cell的抖动，其实是cell移动到当前显示的最下方时让collection往下滚动
-(void)ad_edgeScroll{
    //设置滚动的方向
    [self ad_setScrollDirection];
    //通过滚动的方向修改x,y
    switch (_scrollDirection) {
        case ADDrawCellCollectionViewScrollDirectionLeft:{
            //这里的动画必须设为NO
            [self setContentOffset:CGPointMake(self.contentOffset.x - 4, self.contentOffset.y) animated:NO];
            
            _tempMoveCell.center = CGPointMake(_tempMoveCell.center.x - 4, _tempMoveCell.center.y);
            _lastPoint.x -= 4;
            
        }
             break;
        case ADDrawCellCollectionViewScrollDirectionRight:{
            
            [self setContentOffset:CGPointMake(self.contentOffset.x +4, self.contentOffset.y) animated:NO];
            _tempMoveCell.center = CGPointMake(_tempMoveCell.center.x +4, _tempMoveCell.center.y);
            _lastPoint.x += 4 ;
            
        }
        case ADDrawCellCollectionViewScrollDirectionUp:{
            [self setContentOffset:CGPointMake(self.contentOffset.x, self.contentOffset.y - 4) animated:NO];
            _tempMoveCell.center = CGPointMake(_tempMoveCell.center.x, _tempMoveCell.center.y - 4);
            _lastPoint.y -= 4;
        }
        case ADDrawCellCollectionViewScrollDirectionDown:{
            [self setContentOffset:CGPointMake(self.contentOffset.x, self.contentOffset.y +4 ) animated:NO];
            _tempMoveCell.center = CGPointMake(_tempMoveCell.center.x, _tempMoveCell.center.y + 4);
            _lastPoint.y += 4;
        }
            break;
            
        default:
            break;
    }
    
}



#pragma mark - 设置滚动的方向
-(void)ad_setScrollDirection{
    _scrollDirection = ADDrawCellCollectionViewScrollDirectionNone;
    
    if (self.bounds.size.height + self.contentOffset.y - _tempMoveCell.center.y  < _tempMoveCell.bounds.size.height / 2 && self.bounds.size.height + self.contentOffset.y < self.contentSize.height) {
    
        _scrollDirection = ADDrawCellCollectionViewScrollDirectionDown;
    }
    
    if (_tempMoveCell.center.y - self.contentOffset.y < _tempMoveCell.bounds.size.height / 2 && self.contentOffset.y > 0) {
        _scrollDirection = ADDrawCellCollectionViewScrollDirectionUp;
    }

    
    if (self.bounds.size.width + self.contentOffset.x - _tempMoveCell.center.x < _tempMoveCell.bounds.size.width / 2 && self.bounds.size.width + self.contentOffset.x < self.contentSize.width) {
        _scrollDirection = ADDrawCellCollectionViewScrollDirectionRight;
    }
    
    if (_tempMoveCell.center.x - self.contentOffset.x < _tempMoveCell.bounds.size.width / 2 && self.contentOffset.x > 0) {
        _scrollDirection = ADDrawCellCollectionViewScrollDirectionLeft;
    }
    
}


#pragma mark - 开始所有cell的抖动
-(void)ad_shakeAllCell{

    //关键帧动画
    //在指定的时间（duration）内，依次显示values数组中的每一个关键帧
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animation];
    //帧动画为旋转
    anim.keyPath = @"transform.rotation";
    //根据值生成一个关键帧所需的旋转角度
    anim.values = @[@(angelToRandian(-_shakeLevel)),@(angelToRandian(_shakeLevel)),@(angelToRandian(-_shakeLevel))];
    anim.repeatCount = MAXFLOAT;
    anim.duration = 0.2;
    NSArray *cells = [self visibleCells];
    for (UICollectionViewCell *cell in cells) {
        //如果加了shake动画就不用再添加了
        if (![cell.layer animationForKey:@"shake"]) {
            [cell.layer addAnimation:anim forKey:@"shake"];
        }
    }
    if (![_tempMoveCell.layer animationForKey:@"shake"]) {
        [_tempMoveCell.layer addAnimation:anim forKey:@"shake"];
    }
    
}

#pragma mark - 停止所有cell的抖动状态
-(void)ad_stopShakeAllCell{
    
    if (!_shakeWhenMoveing || _editing) {
        return;
    }
    NSArray *cells = [self visibleCells];
    for (UICollectionViewCell *cell in cells) {
        [cell.layer removeAllAnimations];
    }
    [_tempMoveCell.layer removeAllAnimations];
    [self removeObserver:self forKeyPath:@"contentOffset"];
    
}


#pragma mark - cell移动时，在此方法里判断cell的滚动与位置是否更换
-(void)ad_moveCell{
    
    for (UICollectionViewCell *cell in [self visibleCells]) {
        
        //如果是正在移动的cell就不操作
        if ([self indexPathForCell:cell] == _originalIndexPath) {
            continue;
        }
        
        //计算中心距
        CGFloat spacingX = fabs(_tempMoveCell.center.x - cell.center.x);
        CGFloat spacingY = fabs(_tempMoveCell.center.y - cell.center.y);
        
        //宽高有一半重叠就更新数据源,通过更新数据源把cell插入或移动到需要到达的数组位置
        if (spacingX <= _tempMoveCell.bounds.size.width / 2.0f && spacingY <= _tempMoveCell.bounds.size.height / 2.0f) {
            
            _moveIndexPath = [self indexPathForCell:cell];
            //更新数据源
            //在更新数据源时已经把cell插入或移动到需要到达的位置
            //不过是通过数组的调用，所以需要告诉collectionView把原来的item移动到这里
            [self ad_updateDataSource];
            
            //直接让CollectionView移动item
            [self moveItemAtIndexPath:_originalIndexPath toIndexPath:_moveIndexPath];
            //通知代理
            if ([self.delegate respondsToSelector:@selector(dragCellCollectionView:moveCellFromIndexPath:toIndexPath:)]) {
                [self.delegate dragCellCollectionView:self moveCellFromIndexPath:_originalIndexPath toIndexPath:_moveIndexPath];
            }
            //设置移动前的indexPath为移动后的indexPath
            _originalIndexPath = _moveIndexPath;
            break;
        }
        
        
    }
    
}


#pragma mark - 更新数据源，通过更新数据源把cell插入或移动到需要到达的数组位置
-(void)ad_updateDataSource{
    NSMutableArray *temp = @[].mutableCopy;
    //获取数据源
    if ([self.dataSource respondsToSelector:@selector(dataSourceArrayOfCollectionView:)]) {
        //通过代理对象调用的代理方法获取值
        [temp addObjectsFromArray:[self.dataSource dataSourceArrayOfCollectionView:self]];
    }
    
    //判断数据源是单个数组还是数组套数组的多section形式，YES表示数组套数组
    //当前组数不是一组，或者当前组数是一组但修改后的组数不是一组
    BOOL dataTypeCheck = ([self numberOfSections]!= 1 ||([self numberOfSections] == 1 && [temp[0] isKindOfClass:[NSArray class]]));
    if (dataTypeCheck) {
        //先将数据源的数组都变为可变数据方便操作
        //mutableCopy深拷贝
        for (int i = 0; i < temp.count; i++) {
            [temp replaceObjectAtIndex:i withObject:[temp[i] mutableCopy]];
        }
    }
       //在同一个section中移动或者只有一个section的情况
    if (_moveIndexPath.section == _originalIndexPath.section) {
   
        //如果只有一个数组，则就是当前数组如果是多数组则就是数组temp
        //将原位置和新位置之间的cell向前或者向后平移
        NSMutableArray *orignalSection = dataTypeCheck ? temp[_originalIndexPath.section] :temp;
        //移动的Cell在交换的cell之前，就将移动的cell之后的cell往前移
        if (_moveIndexPath.item > _originalIndexPath.item) {
            for (NSUInteger i = _originalIndexPath.item; i < _moveIndexPath.item; i++) {
                [orignalSection exchangeObjectAtIndex:i withObjectAtIndex:i+1];
            }
        }
        //否则就是往后移
        else{
            for (NSUInteger i = _originalIndexPath.item; i > _moveIndexPath.item; i--) {
                [orignalSection exchangeObjectAtIndex:i withObjectAtIndex:i-1];
            }
        }

    }
     //位于不同组的情况下,将cell从原本所在的数组里移除插入到新的数组里
    else{
        //先获取移动的cell和交换的cell所在组都有多少行
        NSMutableArray *orignalSection = temp[_originalIndexPath.section];
        NSMutableArray *cuurentSection = temp[_moveIndexPath.section];
        //将移动的cell插入到交换的cell所在组的所在位置
        [cuurentSection insertObject:orignalSection[_originalIndexPath.item] atIndex:_moveIndexPath.item];
         //而后将移动的Cell所在组里的原有自身Cell移除
        [orignalSection removeObject:orignalSection[_originalIndexPath.item]];
        
    }
    //将重新排好的数据传递给外部
    if ([self.delegate respondsToSelector:@selector(dragCellCollectionView:newDataArrayAfterMove:)]) {
        [self.delegate dragCellCollectionView:self newDataArrayAfterMove:temp.copy];
    }

}


#pragma mark - 进入编辑模式
-(void)ad_enterEditingModel{
    _editing = YES;
    _oldMinimumPressDuration = _longPressGesture.minimumPressDuration;
    _longPressGesture.minimumPressDuration = 0;
    //判断cell是否已经在抖动，如果没有就抖动
    if (_shakeWhenMoveing) {
        [self ad_shakeAllCell];
        //给自身注册一个监听对象，监听自己的contentOffset值,只要值变了就全部cell抖动
        [self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        //当app将要进入前台的时候注册一个通知
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(ad_foregroud) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
}


#pragma mark - 停止编辑模式
-(void)ad_stopEditingModel{
    _editing = NO;
    _longPressGesture.minimumPressDuration = _oldMinimumPressDuration;
    [self ad_stopShakeAllCell];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}



#pragma mark - 重写hitTest事件，判断是否应该相应自己的滑动手势，还是系统的滑动手势
-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    
    //通过手势所接触的点是否在collectionView上来判断手势是否启动
    _longPressGesture.enabled = [self indexPathForItemAtPoint:point];
    return [super hitTest:point withEvent:event];
    
}


#pragma mark - 重写系统的事件监听
-(void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context{
   //通过observering判断contentOffset是否重复监听
    if ([keyPath isEqualToString:@"contentOffset"]) {
       
        if (_observering) {
            return;
        }else{
            _observering = YES;
        }
    }
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

#pragma mark - 移除通知
-(void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath{
    if ([keyPath isEqualToString:@"contentOffset"]) {
        //通过observering判断contentOffset是否重复移除
        if (!_observering) {
            return;
        }else{
            _observering = NO;
        }
    }
    [super removeObserver:observer forKeyPath:keyPath];
}


#pragma mark - KVO重写,监听到的时候让所有cell抖动
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    [self ad_shakeAllCell];
}


#pragma mark - 回到前台时的判断
-(void)ad_foregroud{
    if (_editing) {
        [self ad_shakeAllCell];
    }
}










@end
