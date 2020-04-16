#import <Foundation/Foundation.h>
#include "Tweak.h"

/**
 * Preferences Bundle
 */
BOOL noads;
BOOL disablereadreceipt;
BOOL disabletypingindicator;
BOOL disablestoryseenreceipt;
BOOL hidesearchbar;
BOOL hidestoriesrow;
BOOL hidepeopletab;

static void reloadPrefs() {
  NSDictionary *settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.haoict.messengernoadspref.plist"];

  noads = [[settings objectForKey:@"noads"]?:@(YES) boolValue];
  disablereadreceipt = [[settings objectForKey:@"disablereadreceipt"]?:@(YES) boolValue];
  disabletypingindicator = [[settings objectForKey:@"disabletypingindicator"]?:@(YES) boolValue];
  disablestoryseenreceipt = [[settings objectForKey:@"disablestoryseenreceipt"]?:@(YES) boolValue];
  hidesearchbar = [[settings objectForKey:@"hidesearchbar"]?:@(NO) boolValue];
  hidestoriesrow = [[settings objectForKey:@"hidestoriesrow"]?:@(NO) boolValue];
  hidepeopletab = [[settings objectForKey:@"hidepeopletab"]?:@(NO) boolValue];
}
static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  reloadPrefs();
}

/**
 * Tweak's hooking code
 */

%group NoAdsNoStoriesRow
  %hook MSGThreadListDataSource
    - (NSArray *)inboxRows {
      NSArray *orig = %orig;
      if (![orig count]) {
        return orig;
      }

      NSMutableArray *resultRows = [@[] mutableCopy];

      if (!(hidestoriesrow && [orig[0][2] isKindOfClass:[NSArray class]] && [orig[0][2][1] isEqual:@"montage_renderer"])) {
        [resultRows addObject:orig[0]];
      }

      for (int i = 1; i < [orig count]; i++) {
        NSArray *row = orig[i];
        if (!noads || (noads && [row[1] intValue] != 2)) {
          [resultRows addObject:row];
        }
      }

      return resultRows;
    }
  %end
%end

%group DisableReadReceipt
  %hook LSMessageListViewController
    - (void)_sendReadReceiptIfNeeded {
      return;
    }
  %end
%end

%group DisableTypingIndicator
  %hook LSTextView
    unsigned long previousLength = 0;
    - (void)updateTextViewForTextChangedAnimated:(BOOL)arg1 {
      [self updateSizeAnimated:arg1];
      self.collapsed = false;
      // only update composer bar state when text is empty or has only one character
      // howerver, in case user first input is emoji, text.length is not 1
      // and emoji length is not constantly 2, some emoji's length are even 11 (family emoji)
      if (![self hasText] || previousLength == 0) {
        [[%c(LSComposerViewController) sharedInstance] updateComposerBarState];
      }

      UILabel *placeholderLabel = MSHookIvar<UILabel *>(self, "_placeholderLabel");
      if ([self hasText]) {
        [[%c(LSComposerViewController) sharedInstance] setTextChangedSinceTextViewCollapsed:true];
        placeholderLabel.text  = @"";
      } else {
        placeholderLabel.text  = @"Aa";
      }
      previousLength = [self.text length];
    }
  %end

  %hook LSComposerViewController
    static LSComposerViewController *__weak sharedInstance;

    - (id)initWithMailbox:(id)arg1 mediaManager:(id)arg2 generatedImageManager:(id)arg3 audioSessionManager:(id)arg4 backgroundTaskManager:(id)arg5 composerTheme:(id)arg6 composerConfiguration:(id)arg7 threadViewContextUniqueIdentifier:(id)arg8 textInputContextIdentifier:(id)arg9 composerState:(id)arg10 composerExtendedSendBlock:(id)arg11 {
      id original = %orig;
      sharedInstance = original;
      return original;
    }

    %new
    + (id)sharedInstance {
      return sharedInstance;
    }
  %end
%end

%group DisableStorySeenReceipt
  %hook LSStoryBucketViewControllerBase
    - (void)viewDidAppear:(_Bool)arg1 {
      LSVideoPlayerView *_videoPlayerView = MSHookIvar<LSVideoPlayerView *>(self, "_videoPlayerView");
      [_videoPlayerView startPlayMedia];
    }

    - (void)moveToNextStoryThread {
      %orig;
      LSVideoPlayerView *_videoPlayerView = MSHookIvar<LSVideoPlayerView *>(self, "_videoPlayerView");
      [_videoPlayerView startPlayMedia];
    }

    - (void)moveToPreviousStoryThread {
      %orig;
      LSVideoPlayerView *_videoPlayerView = MSHookIvar<LSVideoPlayerView *>(self, "_videoPlayerView");
      [_videoPlayerView startPlayMedia];
    }
  %end
%end

%group HidePeopleTab
  %hook UITabBarController
    - (UITabBar *)tabBar {
      UITabBar *orig = %orig;
      orig.hidden = true;
      return orig;
    }
  %end
%end

%group HideSearchBar
  %hook UINavigationController
    - (void)_createAndAttachSearchPaletteForTransitionToTopViewControllerIfNecesssary:(id)arg1 {
    }
  %end
%end




/**
 * Constructor
 */
%ctor {
  dlopen([[[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks/NotInCore.framework/NotInCore"] UTF8String], RTLD_NOW);

  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, CFSTR("com.haoict.messengernoadspref/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  reloadPrefs();

  %init(NoAdsNoStoriesRow);

  if (disablereadreceipt) {
    %init(DisableReadReceipt);
  }

  if (disabletypingindicator) {
    %init(DisableTypingIndicator);
  }

  if (disablestoryseenreceipt) {
    %init(DisableStorySeenReceipt);
  }

  if (hidesearchbar) {
    %init(HideSearchBar);
  }

  if (hidepeopletab) {
    %init(HidePeopleTab);
  }
}

