//
//  ADCell.m
//  cell的拖曳
//
//  Created by 王奥东 on 16/7/11.
//  Copyright © 2016年 王奥东. All rights reserved.
//

#import "ADCell.h"
#import "ADCellModel.h"

@interface ADCell()
@property(nonatomic,strong)UILabel *label;

@end

@implementation ADCell

//初始化时添加一个Label
-(instancetype)initWithFrame:(CGRect)frame{
   
    if (self = [super initWithFrame:frame]) {
        _label = [[UILabel alloc]initWithFrame:self.bounds];
        _label.textColor = [UIColor blackColor];
        _label.textAlignment = UITextAlignmentCenter;
        _label.font = [UIFont systemFontOfSize:14];
        [self addSubview:_label];
    }
    return self;
}



-(void)setData:(ADCellModel *)data{
 
    _data = data;
    _label.text = data.title;
    self.backgroundColor = data.backGroundColor;

 
}


@end
