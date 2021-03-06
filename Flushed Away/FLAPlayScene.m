//
//  FLAMyScene.m
//  Flushed Away
//
//  Created by Jonathan on 9/10/13.
//  Copyright (c) 2013 Piglettens, Ltd. All rights reserved.
//

#import "FLAPlayScene.h"
#import "FLAWorldNode.h"
#import "FLASoundQueue.h"
#import "FLAEndGameNode.h"

@interface FLAPlayScene ()
<SKPhysicsContactDelegate>

@property (nonatomic, strong) FLAWorldNode *world;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) SKLabelNode *timeLabelNode;

@property (nonatomic) BOOL gameEnded, gameEnding;

@property (nonatomic, assign) NSTimeInterval startTimeInterval;

@end

@implementation FLAPlayScene

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        self.backgroundColor = [SKColor blackColor];

        // Setting this anchor point makes it easier since all our calculations
        // will be around the center
        self.anchorPoint = CGPointMake (0.5, 0.5);

        self.physicsWorld.gravity = CGVectorMake(0, 0);
        self.physicsWorld.contactDelegate = self;

        [self resetScene];
    }
    return self;
}

- (void)update:(NSTimeInterval)currentTime
{
    [self.world update:currentTime];
    
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = currentTime;
    }

    if (!self.gameEnded) {
        NSTimeInterval newTime = currentTime - self.startTimeInterval;
        self.timeLabelNode.text = [NSString stringWithFormat:@"%0.1fs", newTime];
    }
}

- (void)resetScene
{
    [self removeAllChildren];
    [self removeAllActions];

    self.gameEnded = NO;
    self.gameEnding = NO;
    self.startTimeInterval = 0;

    self.world = [FLAWorldNode node];
    [self addChild:self.world];
    [self.world setup];

    self.timeLabelNode = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Bold"];
    self.timeLabelNode.fontSize = 12;
    self.timeLabelNode.fontColor = [SKColor yellowColor];
    self.timeLabelNode.text = @"0.0";
    self.timeLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    self.timeLabelNode.position = CGPointMake(0-self.size.width/2+10, self.size.height/2 - 40);
    self.timeLabelNode.alpha = 1;
    [self addChild:self.timeLabelNode];

    self.progressView.progress = 1.0;

    self.paused = NO;

    [self startSounds];
}

- (void)didMoveToView:(SKView *)view
{
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progress = 1.0;

    self.progressView.tintColor = [UIColor redColor];
    self.progressView.frame = CGRectMake(10, self.size.height - 20, 100, 10);
    [self.view addSubview:self.progressView];
}


#pragma mark - Contact Handling

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    NSAssert([contact.bodyA.node conformsToProtocol:@protocol(FLACollisionNode)], nil);
    NSAssert([contact.bodyB.node conformsToProtocol:@protocol(FLACollisionNode)], nil);
    [(SKNode<FLACollisionNode> *)contact.bodyA.node collidedWith:contact.bodyB.node];
    [(SKNode<FLACollisionNode> *)contact.bodyB.node collidedWith:contact.bodyA.node];
}

- (void)boat:(FLABoatNode *)boat sankDownDrain:(FLADrainNode *)drain
{
    [self sinkNode:(SKNode *)boat completion:^{
        [self endGame];
    }];
}

- (void)toy:(FLAToyNode *)toy sankDownDrain:(FLADrainNode *)drain
{
    [self sinkNode:(SKNode *)toy completion:nil];
}

- (void)sinkNode:(SKNode *)node completion:(dispatch_block_t)completion
{
    node.physicsBody.linearDamping = 10;
    node.physicsBody.angularVelocity = 15;
    node.physicsBody.affectedByGravity = NO;
    SKAction *drown = [SKAction sequence:@[
                                           [SKAction scaleTo:0 duration:0.3],
                                           [SKAction runBlock:completion],
                                           [SKAction removeFromParent]
                                           ]];
    [node runAction:drown];
}

- (void)startSounds
{
    [[FLASoundQueue sharedSoundQueue] queueSoundFileNamed:@"action_a_music" loop:NO];
    [[FLASoundQueue sharedSoundQueue] queueSoundFileNamed:@"action_b_music_loop" loop:YES];
    [[FLASoundQueue sharedSoundQueue] start];
}

- (void)playFlushSound
{
    SKAction *flush = [SKAction playSoundFileNamed:@"toilet_flush_fx.aif" waitForCompletion:NO];
    [self runAction:flush];
}

- (void)boat:(FLABoatNode *)boat healthDidChange:(CGFloat)health
{
    self.progressView.progress = health / 100;
    
    if (self.progressView.progress <= 0) {
        [self sinkNode:(SKNode *)boat completion:^{
            [self endGame];
        }];
    }
}

- (void)endGame
{
    if (self.gameEnded) return;

    self.gameEnded = YES;

    [self playFlushSound];

    [self.world runAction:[SKAction fadeAlphaTo:0.3 duration:1]];

    [[FLASoundQueue sharedSoundQueue] fadeOutCompletion:nil];

    self.gameEnding = YES;
    FLAEndGameNode *node = [FLAEndGameNode node];
    [self addChild:node];
    [node runAction:[SKAction sequence:@[
                                         [SKAction fadeAlphaTo:1 duration:1],
                                         [SKAction waitForDuration:1],
                                         [SKAction runBlock:^{
        self.gameEnding = NO;
    }]]]];
}


#pragma mark - Passing on touches to world

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.gameEnding) return;
    [self.world touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.gameEnding) return;
    [self.world touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.gameEnding) return;

    if (self.gameEnded) {
        [self resetScene];
    } else {
        [self.world touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.gameEnding) return;
    [self.world touchesCancelled:touches withEvent:event];
}

@end
