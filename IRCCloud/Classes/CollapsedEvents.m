//
//  CollapsedEvents.m
//
//  Copyright (C) 2013 IRCCloud, Ltd.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


#import "CollapsedEvents.h"
#import "ColorFormatter.h"
#import "NetworkConnection.h"

@implementation CollapsedEvent
-(NSComparisonResult)compare:(CollapsedEvent *)aEvent {
    if(_type == aEvent.type) {
        if(_eid < aEvent.eid)
            return NSOrderedAscending;
        else
            return NSOrderedDescending;
    } else if(_type < aEvent.type) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}
-(NSString *)description {
    return [NSString stringWithFormat:@"{type: %i, chan: %@, nick: %@, oldNick: %@, hostmask: %@, fromMode: %@, targetMode: %@, modes: %@, msg: %@, netsplit: %i}", _type, _chan, _nick, _oldNick, _hostname, _fromMode, _targetMode, [self modes:YES], _msg, _netsplit];
}
-(BOOL)addMode:(NSString *)mode {
    if([mode rangeOfString:@"q"].location != NSNotFound) {
        if(_modes[kCollapsedModeDeOwner])
            _modes[kCollapsedModeDeOwner] = false;
        else
            _modes[kCollapsedModeOwner] = true;
    } else if([mode rangeOfString:@"a"].location != NSNotFound) {
        if(_modes[kCollapsedModeDeAdmin])
            _modes[kCollapsedModeDeAdmin] = false;
        else
            _modes[kCollapsedModeAdmin] = true;
    } else if([mode rangeOfString:@"o"].location != NSNotFound) {
        if(_modes[kCollapsedModeDeOp])
            _modes[kCollapsedModeDeOp] = false;
        else
            _modes[kCollapsedModeOp] = true;
    } else if([mode rangeOfString:@"h"].location != NSNotFound) {
        if(_modes[kCollapsedModeDeHalfOp])
            _modes[kCollapsedModeDeHalfOp] = false;
        else
            _modes[kCollapsedModeHalfOp] = true;
    } else if([mode rangeOfString:@"v"].location != NSNotFound) {
        if(_modes[kCollapsedModeDeVoice])
            _modes[kCollapsedModeDeVoice] = false;
        else
            _modes[kCollapsedModeVoice] = true;
    } else {
        return NO;
    }
    if([self modeCount] == 0)
        return [self addMode:mode];
    return YES;
}
-(BOOL)removeMode:(NSString *)mode {
    if([mode rangeOfString:@"q"].location != NSNotFound) {
        if(_modes[kCollapsedModeOwner])
            _modes[kCollapsedModeOwner] = false;
        else
            _modes[kCollapsedModeDeOwner] = true;
    } else if([mode rangeOfString:@"a"].location != NSNotFound) {
        if(_modes[kCollapsedModeAdmin])
            _modes[kCollapsedModeAdmin] = false;
        else
            _modes[kCollapsedModeDeAdmin] = true;
    } else if([mode rangeOfString:@"o"].location != NSNotFound) {
        if(_modes[kCollapsedModeOp])
            _modes[kCollapsedModeOp] = false;
        else
            _modes[kCollapsedModeDeOp] = true;
    } else if([mode rangeOfString:@"h"].location != NSNotFound) {
        if(_modes[kCollapsedModeHalfOp])
            _modes[kCollapsedModeHalfOp] = false;
        else
            _modes[kCollapsedModeDeHalfOp] = true;
    } else if([mode rangeOfString:@"v"].location != NSNotFound) {
        if(_modes[kCollapsedModeVoice])
            _modes[kCollapsedModeVoice] = false;
        else
            _modes[kCollapsedModeDeVoice] = true;
    } else {
        return NO;
    }
    if([self modeCount] == 0)
        return [self removeMode:mode];
    return YES;
}
-(void)_copyModes:(BOOL *)to {
    for(int i = 0; i < sizeof(_modes); i++) {
        to[i] = _modes[i];
    }
}
-(void)copyModes:(CollapsedEvent *)from {
    [from _copyModes:_modes];
}
-(NSString *)modes:(BOOL)showSymbol {
    static NSString *mode_msgs[] = {
        @"promoted to owner",
        @"promoted to admin",
        @"opped",
        @"halfopped",
        @"voiced",
        @"demoted from owner",
        @"demoted from admin",
        @"de-opped",
        @"de-halfopped",
        @"de-voiced"
    };
    static NSString *mode_modes[] = {
        @"+q",
        @"+a",
        @"+o",
        @"+h",
        @"+v",
        @"-q",
        @"-a",
        @"-o",
        @"-h",
        @"-v"
    };
    static NSString *mode_colors[] = {
        @"E7AA00",
        @"6500A5",
        @"BA1719",
        @"B55900",
        @"25B100"
    };
    NSString *output = nil;
    
    if([self modeCount]) {
        output = @"";
        for(int i = 0; i < sizeof(_modes); i++) {
            if(_modes[i]) {
                if(output.length)
                    output = [output stringByAppendingString:@", "];
                output = [output stringByAppendingString:mode_msgs[i]];
                if(showSymbol) {
                    output = [output stringByAppendingFormat:@" (%c%@%@%c)", COLOR_RGB, mode_colors[i%5], mode_modes[i], CLEAR];
                }
            }
        }
    }
    
    return output;
}
-(int)modeCount {
    int count = 0;
    for(int i = 0; i < sizeof(_modes); i++) {
        if(_modes[i])
            count++;
    }
    return count;
}
@end

@implementation CollapsedEvents
-(id)init {
    self = [super init];
    if(self) {
        _data = [[NSMutableArray alloc] init];
    }
    return self;
}
-(void)clear {
    @synchronized(_data) {
        [_data removeAllObjects];
    }
}
-(CollapsedEvent *)findEvent:(NSString *)nick chan:(NSString *)chan {
    @synchronized(_data) {
        for(CollapsedEvent *event in _data) {
            if([[event.nick lowercaseString] isEqualToString:[nick lowercaseString]] && [[event.chan lowercaseString] isEqualToString:[chan lowercaseString]])
                return event;
        }
        return nil;
    }
}
-(void)addCollapsedEvent:(CollapsedEvent *)event {
    @synchronized(_data) {
        CollapsedEvent *e = nil;
        
        if(event.type < kCollapsedEventNickChange) {
            if(event.oldNick.length > 0 && event.type != kCollapsedEventMode) {
                e = [self findEvent:event.oldNick chan:event.chan];
                if(e)
                    e.nick = event.nick;
            }
            
            if(!e)
                e = [self findEvent:event.nick chan:event.chan];
            
            if(e) {
                if(e.type == kCollapsedEventMode) {
                    e.type = event.type;
                    e.msg = event.msg;
                    if(event.fromMode)
                        e.fromMode = event.fromMode;
                    if(event.targetMode)
                        e.targetMode = event.targetMode;
                } else if(e.type == kCollapsedEventNickChange) {
                    e.type = event.type;
                    e.msg = event.msg;
                    e.fromMode = event.fromMode;
                    e.fromNick = event.fromNick;
                } else if(event.type == kCollapsedEventMode) {
                    e.fromMode = event.targetMode;
                } else if(event.type == e.type) {
                } else if(event.type == kCollapsedEventJoin) {
                    e.type = kCollapsedEventPopOut;
                    e.fromMode = event.fromMode;
                } else if(e.type == kCollapsedEventPopOut) {
                    e.type = event.type;
                } else {
                    e.type = kCollapsedEventPopIn;
                }
                e.eid = event.eid;
                e.netsplit = event.netsplit;
                [event copyModes:e];
            } else {
                [_data addObject:event];
            }
        } else {
            if(event.type == kCollapsedEventNickChange) {
                for(CollapsedEvent *e1 in _data) {
                    if(e1.type == kCollapsedEventNickChange && [[e1.nick lowercaseString] isEqualToString:[event.oldNick lowercaseString]]) {
                        if([[e1.oldNick lowercaseString] isEqualToString:[event.nick lowercaseString]]) {
                            [_data removeObject:e1];
                        } else {
                            e1.eid = event.eid;
                            e1.nick = event.nick;
                        }
                        return;
                    }
                    if((e1.type == kCollapsedEventJoin || e1.type == kCollapsedEventPopOut) && [[e1.nick lowercaseString] isEqualToString:[event.oldNick lowercaseString]]) {
                        e1.eid = event.eid;
                        e1.oldNick = event.oldNick;
                        e1.nick = event.nick;
                        return;
                    }
                    if((e1.type == kCollapsedEventQuit || e1.type == kCollapsedEventPart) && [[e1.nick lowercaseString] isEqualToString:[event.oldNick lowercaseString]]) {
                        e1.eid = event.eid;
                        e1.type = kCollapsedEventPopOut;
                        for(CollapsedEvent *e2 in _data) {
                            if(e2.type == kCollapsedEventJoin && [[e2.nick lowercaseString] isEqualToString:[event.oldNick lowercaseString]]) {
                                [_data removeObject:e2];
                                break;
                            }
                        }
                        return;
                    }
                }
                [_data addObject:event];
            } else {
                [_data addObject:event];
            }
        }
    }
}
-(BOOL)addEvent:(Event *)event {
    @synchronized(_data) {
        CollapsedEvent *c;
        if([event.type hasSuffix:@"user_channel_mode"]) {
            c = [self findEvent:event.nick chan:event.chan];
            if(!c) {
                c = [[CollapsedEvent alloc] init];
                c.type = kCollapsedEventMode;
                c.eid = event.eid;
            }
            if(event.ops) {
                for(NSDictionary *op in [event.ops objectForKey:@"add"]) {
                    if(![c addMode:[op objectForKey:@"mode"]])
                        return NO;
                    if(c.type == kCollapsedEventMode) {
                        c.nick = [op objectForKey:@"param"];
                        if(event.from.length) {
                            c.fromNick = event.from;
                            c.fromMode = event.fromMode;
                        } else if(event.server.length) {
                            c.fromNick = event.server;
                            c.fromMode = @"__the_server__";
                        }
                        c.hostname = event.hostmask;
                        c.targetMode = event.targetMode;
                        c.chan = event.chan;
                        [self addCollapsedEvent:c];
                    } else {
                        c.fromMode = event.targetMode;
                    }
                }
                for(NSDictionary *op in [event.ops objectForKey:@"remove"]) {
                    if(![c removeMode:[op objectForKey:@"mode"]])
                        return NO;
                    if(c.type == kCollapsedEventMode) {
                        c.nick = [op objectForKey:@"param"];
                        if(event.from.length) {
                            c.fromNick = event.from;
                            c.fromMode = event.fromMode;
                        } else if(event.server.length) {
                            c.fromNick = event.server;
                            c.fromMode = @"__the_server__";
                        }
                        c.hostname = event.hostmask;
                        c.targetMode = event.targetMode;
                        c.chan = event.chan;
                        [self addCollapsedEvent:c];
                    } else {
                        c.fromMode = event.targetMode;
                    }
                }
            }
        } else {
            c = [[CollapsedEvent alloc] init];
            c.eid = event.eid;
            c.nick = event.nick;
            c.hostname = event.hostmask;
            c.fromMode = event.fromMode;
            c.chan = event.chan;
            if([event.type hasSuffix:@"joined_channel"]) {
                c.type = kCollapsedEventJoin;
            } else if([event.type hasSuffix:@"parted_channel"]) {
                c.type = kCollapsedEventPart;
                c.msg = event.msg;
            } else if([event.type hasSuffix:@"quit"]) {
                c.type = kCollapsedEventQuit;
                c.msg = event.msg;
                if([[NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^(?:[^\\s:\\/.]+\\.)+[a-z]{2,} (?:[^\\s:\\/.]+\\.)+[a-z]{2,}$"] evaluateWithObject:event.msg]) {
                    NSArray *parts = [event.msg componentsSeparatedByString:@" "];
                    if(parts.count > 1 && ![[parts objectAtIndex:0] isEqualToString:[parts objectAtIndex:1]]) {
                        c.netsplit = YES;
                        BOOL match = NO;
                        for(CollapsedEvent *event in _data) {
                            if(event.type == kCollapsedEventNetSplit && [event.msg isEqualToString:event.msg])
                                match = YES;
                        }
                        if(!match && _data.count > 0) {
                            CollapsedEvent *e = [[CollapsedEvent alloc] init];
                            e.type = kCollapsedEventNetSplit;
                            e.msg = event.msg;
                            [_data addObject:e];
                        }
                    }
                }
            } else if([event.type hasSuffix:@"nickchange"]) {
                c.type = kCollapsedEventNickChange;
                c.oldNick = event.oldNick;
            } else {
                return NO;
            }
            [self addCollapsedEvent:c];
        }
        return YES;
    }
}
-(NSString *)was:(CollapsedEvent *)e {
    NSString *output = @"";
    NSString *modes = [e modes:NO];
    
    if(e.oldNick && e.type != kCollapsedEventMode)
        output = [NSString stringWithFormat:@"was %@", e.oldNick];
    if(modes.length) {
        if(output.length > 0)
            output = [output stringByAppendingString:@"; "];
        output = [output stringByAppendingFormat:@"%c1%@%c", COLOR_MIRC, modes, CLEAR];
    }
    
    if(output.length)
        output = [NSString stringWithFormat:@" (%@)", output];
    
    return output;
}
-(NSString *)collapse:(BOOL)showChan {
    @synchronized(_data) {
        NSString *output;
        
        if(_data.count == 0)
            return nil;
        
        if(_data.count == 1 && [[_data objectAtIndex:0] modeCount] < 2) {
            CollapsedEvent *e = [_data objectAtIndex:0];
            switch(e.type) {
                case kCollapsedEventNetSplit:
                    output = [e.msg stringByReplacingOccurrencesOfString:@" " withString:@" ↮ "];
                    break;
                case kCollapsedEventMode:
                    output = [NSString stringWithFormat:@"%@ was %@", [self formatNick:e.nick mode:e.targetMode colorize:NO], [e modes:YES]];
                    if(e.fromNick) {
                        if([e.fromMode isEqualToString:@"__the_server__"])
                            output = [output stringByAppendingFormat:@" by the server %c%@%c", BOLD, e.fromNick, CLEAR];
                        else
                            output = [output stringByAppendingFormat:@" by %@", [self formatNick:e.fromNick mode:e.fromMode colorize:NO]];
                    }
                    break;
                case kCollapsedEventJoin:
                    if(showChan)
                        output = [NSString stringWithFormat:@"→ %@%@ joined %@ (%@)", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e], e.chan, e.hostname];
                    else
                        output = [NSString stringWithFormat:@"→ %@%@ joined (%@)", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e], e.hostname];
                    break;
                case kCollapsedEventPart:
                    if(showChan)
                        output = [NSString stringWithFormat:@"← %@%@ left %@ (%@)", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e], e.chan, e.hostname];
                    else
                        output = [NSString stringWithFormat:@"← %@%@ left (%@)", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e], e.hostname];
                    if(e.msg.length > 0)
                        output = [output stringByAppendingFormat:@": %@", e.msg];
                    break;
                case kCollapsedEventQuit:
                    output = [NSString stringWithFormat:@"⇐ %@%@ quit", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e]];
                    if(e.hostname.length > 0)
                        output = [output stringByAppendingFormat:@" (%@)", e.hostname];
                    if(e.msg.length > 0)
                        output = [output stringByAppendingFormat:@": %@", e.msg];
                    break;
                case kCollapsedEventNickChange:
                    output = [NSString stringWithFormat:@"%@ → %@", e.oldNick, [self formatNick:e.nick mode:e.fromMode colorize:NO]];
                    break;
                case kCollapsedEventPopIn:
                    output = [NSString stringWithFormat:@"↔ %@%@ popped in", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e]];
                    if(showChan)
                        output = [output stringByAppendingFormat:@" %@", e.chan];
                    break;
                case kCollapsedEventPopOut:
                    output = [NSString stringWithFormat:@"↔ %@%@ nipped out", [self formatNick:e.nick mode:e.fromMode colorize:NO], [self was:e]];
                    if(showChan)
                        output = [output stringByAppendingFormat:@" %@", e.chan];
                    break;
            }
        } else {
            BOOL isNetsplit = NO;
            [_data sortUsingSelector:@selector(compare:)];
            NSEnumerator *i = [_data objectEnumerator];
            CollapsedEvent *last = nil;
            CollapsedEvent *next = [i nextObject];
            CollapsedEvent *e;
            int groupcount = 0;
            NSMutableString *message = [[NSMutableString alloc] init];
            
            while(next) {
                e = next;
                
                do {
                    next = [i nextObject];
                } while(isNetsplit && next.netsplit);
                
                if(message.length > 0 && e.type < kCollapsedEventNickChange && ((next == nil || next.type != e.type) && last != nil && last.type == e.type)) {
					if(groupcount == 1) {
                        [message deleteCharactersInRange:NSMakeRange(message.length - 2, 2)];
                        [message appendString:@" "];
                    }
                    [message appendString:@"and "];
				}
                
                if(last == nil || last.type != e.type) {
                    switch(e.type) {
                        case kCollapsedEventNetSplit:
                            isNetsplit = YES;
                            break;
                        case kCollapsedEventMode:
                            if(message.length)
                                [message appendString:@"• "];
                            [message appendFormat:@"%c1mode:%c ", COLOR_MIRC, CLEAR];
                            break;
                        case kCollapsedEventJoin:
                            [message appendString:@"→ "];
                            break;
                        case kCollapsedEventPart:
                            [message appendString:@"← "];
                            break;
                        case kCollapsedEventQuit:
                            [message appendString:@"⇐ "];
                            break;
                        case kCollapsedEventNickChange:
                            if(message.length)
                                [message appendString:@"• "];
                            break;
                        case kCollapsedEventPopIn:
                        case kCollapsedEventPopOut:
                            [message appendString:@"↔ "];
                            break;
                    }
                }
                
                if(e.type == kCollapsedEventNickChange) {
                    [message appendFormat:@"%@ → %@", e.oldNick, [self formatNick:e.nick mode:e.fromMode colorize:NO]];
                    NSString *oldNick = e.oldNick;
                    e.oldNick = nil;
                    [message appendString:[self was:e]];
                    e.oldNick = oldNick;
                } else if(e.type == kCollapsedEventNetSplit) {
                    [message appendString:[e.msg stringByReplacingOccurrencesOfString:@" " withString:@" ↮ "]];
                } else if(!showChan) {
                    [message appendString:[self formatNick:e.nick mode:(e.type == kCollapsedEventMode)?e.targetMode:e.fromMode colorize:NO]];
                    [message appendString:[self was:e]];
                }
                
                if((next == nil || next.type != e.type) && !showChan) {
                    switch(e.type) {
                        case kCollapsedEventJoin:
                            [message appendString:@" joined"];
                            break;
                        case kCollapsedEventPart:
                            [message appendString:@" left"];
                            break;
                        case kCollapsedEventQuit:
                            [message appendString:@" quit"];
                            break;
                        case kCollapsedEventPopIn:
                            [message appendString:@" popped in"];
                            break;
                        case kCollapsedEventPopOut:
                            [message appendString:@" nipped out"];
                            break;
                        default:
                            break;
                    }
                } else if(showChan && e.type != kCollapsedEventNetSplit) {
                    if(groupcount == 0) {
                        [message appendString:[self formatNick:e.nick mode:(e.type == kCollapsedEventMode)?e.targetMode:e.fromMode colorize:NO]];
                        [message appendString:[self was:e]];
                        switch(e.type) {
                            case kCollapsedEventJoin:
                                [message appendString:@" joined "];
                                break;
                            case kCollapsedEventPart:
                                [message appendString:@" left "];
                                break;
                            case kCollapsedEventQuit:
                                [message appendString:@" quit"];
                                break;
                            case kCollapsedEventPopIn:
                                [message appendString:@" popped in "];
                                break;
                            case kCollapsedEventPopOut:
                                [message appendString:@" nipped out "];
                                break;
                            default:
                                break;
                        }
                    }
                    if(e.type != kCollapsedEventQuit && e.chan)
                        [message appendString:e.chan];
                }
                
                if(next != nil && next.type == e.type) {
                    [message appendString:@", "];
                    groupcount++;
                } else if(next != nil) {
                    [message appendString:@" "];
                    groupcount = 0;
                }
                
                last = e;
            }
            output = message;
        }
        
        return output;
    }
}

-(int)count {
    return _data.count;
}

-(NSString *)formatNick:(NSString *)nick mode:(NSString *)mode colorize:(BOOL)colorize {
    if(!_PREFIX) {
        _PREFIX = @{@"q":@"~", @"a":@"&", @"o":@"@", @"h":@"%", @"v":@"+"};
    }
    NSDictionary *mode_colors = @{
        @"q":@"E7AA00",
        @"a":@"6500A5",
        @"o":@"BA1719",
        @"h":@"B55900",
        @"v":@"25B100"
    };
    NSArray *colors = @[@"fc009a", @"ff1f1a", @"d20004", @"fd6508", @"880019", @"c7009c", @"804fc4", @"5200b7", @"123e92", @"1d40ff", @"108374", @"2e980d", @"207607", @"196d61"];
    NSString *color = nil;
    NSMutableString *output = [[NSMutableString alloc] initWithFormat:@"%c", BOLD];
    BOOL showSymbol = [[NetworkConnection sharedInstance] prefs] && [[[[NetworkConnection sharedInstance] prefs] objectForKey:@"mode-showsymbol"] boolValue];
    
    if(colorize) {
        // Normalise a bit
        // typically ` and _ are used on the end alone
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"[`_]+$" options:NSRegularExpressionCaseInsensitive error:nil];
        NSString *normalizedNick = [r stringByReplacingMatchesInString:[nick lowercaseString] options:0 range:NSMakeRange(0, nick.length) withTemplate:@""];
        // remove |<anything> from the end
        r = [NSRegularExpression regularExpressionWithPattern:@"|.*$" options:NSRegularExpressionCaseInsensitive error:nil];
        normalizedNick = [r stringByReplacingMatchesInString:normalizedNick options:0 range:NSMakeRange(0, normalizedNick.length) withTemplate:@""];
        
        double hash = 0;
        long lHash = 0;
        for(int i = 0; i < normalizedNick.length; i++) {
            hash = [normalizedNick characterAtIndex:i] + (double)(lHash << 6) + (double)(lHash << 16) - hash;
            lHash = [[NSNumber numberWithDouble:hash] longValue];
        }
        
        color = [colors objectAtIndex:abs([[NSNumber numberWithDouble:hash] longLongValue] % 14)];
    }
    
    if(mode.length) {
        if([mode rangeOfString:@"q"].location != NSNotFound)
            mode = @"q";
        else if([mode rangeOfString:@"a"].location != NSNotFound)
            mode = @"a";
        else if([mode rangeOfString:@"o"].location != NSNotFound)
            mode = @"o";
        else if([mode rangeOfString:@"h"].location != NSNotFound)
            mode = @"h";
        else if([mode rangeOfString:@"v"].location != NSNotFound)
            mode = @"v";
        else
            mode = [mode substringToIndex:1];
        
        if(showSymbol) {
            if([_PREFIX objectForKey:mode]) {
                if([mode_colors objectForKey:mode]) {
                    [output appendFormat:@"%c%@%@%c ", COLOR_RGB, [mode_colors objectForKey:mode], [_PREFIX objectForKey:mode], COLOR_RGB];
                } else {
                    [output appendFormat:@"%@ ", [_PREFIX objectForKey:mode]];
                }
            }
        } else {
            if([mode_colors objectForKey:mode]) {
                [output appendFormat:@"%c%@•%c ", COLOR_RGB, [mode_colors objectForKey:mode], COLOR_RGB];
            } else {
                [output appendString:@"• "];
            }
        }
    }
    
    if(color) {
        [output appendFormat:@"%c%@%@%c%c", COLOR_RGB, color, nick, COLOR_RGB, BOLD];
    } else {
        [output appendFormat:@"%@%c", nick, BOLD];
    }
    return output;
}
@end
