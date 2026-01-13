//
// uvc-util.m
//
// The utility program that makes use of the UVCController class to handle
// introspection and interaction with software controls exposed by UVC-compliant
// USB video devices.
//
// Copyright © 2016
// Dr. Jeffrey Frey, IT-NSS
// University of Delaware
//
// $Id$
//

#import <Foundation/Foundation.h>
#include <getopt.h>

#import "UVCController.h"
#import "UVCValue.h"

//

#if (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_9)
#define UVC_UTIL_COMPAT_VERSION   "pre-10.9"
#elif (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_10)
#define UVC_UTIL_COMPAT_VERSION   "10.9"
#elif (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_11)
#define UVC_UTIL_COMPAT_VERSION   "10.10"
#else 
#define UVC_UTIL_COMPAT_VERSION   "10.11"
#endif

static NumVersion       UVCUtilVersion = {
                            .majorRev       = 1,
                            .minorAndBugRev = 0x20,
                            .stage          = finalStage,
                            .nonRelRev      = 0
                          };

const char*
UVCUtilVersionString(void)
{
  static char       versionString[64];
  BOOL              ready = NO;
  
  if ( ! ready ) {
    const char      *format;
    
    switch ( UVCUtilVersion.stage ) {
      
      case developStage:
        format = "%1$hhd.%2$1hhx.%3$1hhxdev%4$hhd (for Mac OS X %5$s)";
        break;
        
      case alphaStage:
        format = "%1$hhd.%2$1hhx.%3$1hhxa%4$hhd (for Mac OS X %5$s)";
        break;
    
      case betaStage:
        format = "%1$hhd.%2$1hhx.%3$1hhxb%4$hhd (for Mac OS X %5$s)";
        break;
    
      case finalStage:
        format = ( UVCUtilVersion.minorAndBugRev &0xF ) ? "%1$hhd.%2$1hhx.%3$1hhx (for Mac OS X %5$s)" : "%1$hhd.%2$1hhx (for Mac OS X %5$s)";
        break;
    
    }
    snprintf(versionString, sizeof(versionString), format,
                UVCUtilVersion.majorRev,
                ((UVCUtilVersion.minorAndBugRev & 0xF0) >> 4),
                (UVCUtilVersion.minorAndBugRev & 0xF),
                UVCUtilVersion.nonRelRev,
                UVC_UTIL_COMPAT_VERSION
              );
  }
  
  return (const char*)versionString;
}

//
                          
static struct option uvcUtilOptions[] = {
                                         { "list-devices",                    no_argument,       NULL, 'd' },
                                         { "list-controls",                   no_argument,       NULL, 'c' },
                                         { "show-control",                    required_argument, NULL, 'S' },
                                         { "set",                             required_argument, NULL, 's' },
                                         { "get",                             required_argument, NULL, 'g' },
                                         { "get-value",                       required_argument, NULL, 'o' },
                                         { "reset-all",                       no_argument,       NULL, 'r' },
                                         { "select-none",                     no_argument,       NULL, '0' },
                                         { "select-by-vendor-and-product-id", required_argument, NULL, 'V' },
                                         { "select-by-location-id",           required_argument, NULL, 'L' },
                                         { "select-by-name",                  required_argument, NULL, 'N' },
                                         { "select-by-index",                 required_argument, NULL, 'I' },
                                         { "keep-running",                    no_argument,       NULL, 'k' },
                                         { "help",                            no_argument,       NULL, 'h' },
                                         { "version",                         no_argument,       NULL, 'v' },
                                         // We don't publish the existence of the --debug/-D flag:
                                         { "debug",                           no_argument,       NULL, 'D' },
                                         { NULL,                              0,                 NULL,  0  }
                                       };

//

void
usage(
  const char  *exe
)
{
  printf(
      "usage:\n"
      "\n"
      "    %s {options/actions/target selection}\n"
      "\n"
      "  Options:\n"
      "\n"
      "    -h/--help                              Show this information\n"
      "    -v/--version                           Show the version of the program\n"
      "    -k/--keep-running                      Continue processing additional actions despite\n"
      "                                           encountering errors\n"
      "\n"
      "  Actions:\n"
      "\n"
      "    -d/--list-devices                      Display a list of all UVC-capable devices\n"
      "    -c/--list-controls                     Display a list of UVC controls implemented\n"
      "\n"
      "    Available after a target device is selected:\n"
      "\n"
      "    -c/--list-controls                     Display a list of UVC controls available for\n"
      "                                           the target device\n"
      "\n"
      "    -S (<control-name>|*)                  Display available information for the given\n"
      "    --show-control=(<control-name>|*)      UVC control (or all controls for \"*\").  Component\n"
      "                                           fields for multi-component controls, minimum, maximum,\n"
      "                                           resolution, and default value when provided:\n"
      "\n"
      "        pan-tilt-abs {\n"
      "          type-description: {\n"
      "            signed 32-bit integer            pan;\n"
      "            signed 32-bit integer            tilt;\n"
      "          },\n"
      "          minimum: {pan=-648000,tilt=-648000}\n"
      "          maximum: {pan=648000,tilt=648000}\n"
      "          step-size: {pan=3600,tilt=3600}\n"
      "          default-value: {pan=0,tilt=0}\n"
      "        }\n"
      "\n"
      "    -g <control-name>                      Get the value of a control.\n"
      "    --get=<control-name>\n"
      "\n"
      "    -o <control-name>                      Same as -g/--get, but ONLY the value of the control\n"
      "    --get-value=<control-name>             is displayed (no label)\n"
      "\n"
      "    -s <control-name>=<value>              Set the value of a control; see below for a\n"
      "    --set=<control-name>=<value>           description of <value>\n"
      "\n"
      "    -r/--reset-all                         Reset all controls with a default value to that value\n"
      "\n"
      "    Specifying <value> for -s/--set:\n"
      "\n"
      "      * The string \"default\" indicates the control should be reset to its default value(s)\n"
      "        (if available)\n"
      
      "      * The string \"minimum\" indicates the control should be reset to its minimum value(s)\n"
      "        (if available)\n"
      
      "      * The string \"maximum\" indicates the control should be reset to its maximum value(s)\n"
      "        (if available)\n"
      "\n"
      "      * Multi-component controls must provide a list of per-component values.  The values may\n"
      "        be specified either in the same sequence as shown by the -S/--show-control, or by naming\n"
      "        each value.  For example, the \"pan-tilt-abs\" control has two components, \"pan\" and\n"
      "        \"tilt\" (in that order), so the following are equivalent:\n"
      "\n"
      "            -s pan-tilt-abs=\"{-3600, 36000}\"\n"
      "            -s pan-tilt-abs=\"{tilt=0.52778, pan=-3600}\"\n"
      "\n"
      "      * Single-value controls should not use the brace notation, just the component value of the\n"
      "        control, for example:\n"
      "\n"
      "            -s brightness=0.5\n"
      "\n"
      "      * Component values may be provided as fractional values (in the range [0,1]) if the control\n"
      "        provides a value range (can be checked using -S/--show-control).  The value \"0.0\"\n"
      "        corresponds to the minimum, \"1.0\" to the maximum.\n"
      "\n"
      "      * Component values may use the strings \"default,\" \"minimum,\" or \"maximum\" to indicate that\n"
      "        the component's default, minimum, or maximum value should be used (if the control provides one,\n"
      "        can be checked using -S/--show-control)\n"
      "\n"
      "            -s pan-tilt-abs=\"{default,minimum}\"\n"
      "            -s pan-tilt-abs=\"{tilt=-648000,pan=default}\"\n"
      "\n"
      "  Methods for selecting the target device:\n"
      "\n"
      "    -0\n"
      "    --select-none\n"
      "\n"
      "         Drop the selected target device\n"
      "\n"
      "    -I <device-index>\n"
      "    --select-by-index=<device-index>\n"
      "\n"
      "         Index of the device in the list of all devices (zero-based)\n"
      "\n"
      "    -V <vendor-id>:<product-id>\n"
      "    --select-by-vendor-and-product-id=<vendor-id>:<product-id>\n"
      "\n"
      "         Provide the hexadecimal- or integer-valued vendor and product identifier\n"
      "         (Prefix hexadecimal values with \"0x\")\n"
      "\n"
      "    -L <location-id>\n"
      "    --select-by-location-id=<location-id>\n"
      "\n"
      "         Provide the hexadecimal- or integer-valued USB locationID attribute\n"
      "         (Prefix hexadecimal values with \"0x\")\n"
      "\n"
      "    -N <device-name>\n"
      "    --select-by-name=<device-name>\n"
      "\n"
      "         Provide the USB product name (e.g. \"AV.io HDMI Video\")\n"
      "\n",
      exe
    );
}

//

void printJSON(id object) {
    if (object) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
        if (jsonData) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("%s\n", [jsonString UTF8String]);
            [jsonString release];
        } else {
            fprintf(stderr, "JSON Error: %s\n", [[error localizedDescription] UTF8String]);
        }
    }
}

void printError(NSString *msg, int code) {
    NSDictionary *err = [NSDictionary dictionaryWithObjectsAndKeys:
        msg, @"error",
        [NSNumber numberWithInt:code], @"code",
        nil];
    NSError *e = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:err options:NSJSONWritingPrettyPrinted error:&e];
    if(data) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        fprintf(stderr, "%s\n", [s UTF8String]);
        [s release];
    }
}

//

UVCController*
UVCUtilGetControllerWithName(
  NSArray     *uvcDevices,
  NSString    *name
)
{
  NSEnumerator  *eDevices = [uvcDevices objectEnumerator];
  UVCController *controller;
  
  while ( (controller = [eDevices nextObject]) ) {
    if ( [name compare:[controller deviceName] options:NSCaseInsensitiveSearch] == NSOrderedSame ) return controller;
  }
  return nil;
}

//

UVCController*
UVCUtilGetControllerWithVendorAndProductId(
  NSArray         *uvcDevices,
  unsigned short  vendorId,
  unsigned short  productId
)
{
  NSEnumerator  *eDevices = [uvcDevices objectEnumerator];
  UVCController *controller;
  
  while ( (controller = [eDevices nextObject]) ) {
    if ( ([controller vendorId] == vendorId) && ([controller productId] == productId) ) return controller;
  }
  return nil;
}

//

UVCController*
UVCUtilGetControllerWithLocationId(
  NSArray         *uvcDevices,
  unsigned        locationId
)
{
  NSEnumerator  *eDevices = [uvcDevices objectEnumerator];
  UVCController *controller;
  
  while ( (controller = [eDevices nextObject]) ) {
    if ( [controller locationId] == locationId ) return controller;
  }
  return nil;
}

//

int
main(
  int               argc,
  char*             argv[]
)
{
  const char        *exe = argv[0];
  int               rc = 0;
  NSArray           *uvcDevices = nil;
  UVCController     *targetDevice = nil;
  int               optCh;
  BOOL              exitOnErrors = YES;
  UVCTypeScanFlags  uvcScanFlags = kUVCTypeScanFlagShowWarnings;
  
  //
  // No CLI arguments, we've got nothing to do:
  //
  if ( argc == 1 ) {
    usage(argv[0]);
    return 0;
  }

@autoreleasepool {
  while ( (optCh = getopt_long(argc, argv, "dcS:s:g:o:r0V:L:N:I:khfFvD", uvcUtilOptions, NULL)) != -1 ) {
    switch ( optCh ) {
    
      case 'h': {
        usage(exe);
        break;
      }
      
      case 'v': {
        NSDictionary *ver = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithUTF8String:UVCUtilVersionString()], @"version",
            [NSString stringWithFormat:@"%s %s", __TIME__, __DATE__], @"build_timestamp",
            nil];
        printJSON(ver);
        break;
      }
      
      case 'k': {
        exitOnErrors = NO;
        break;
      }
      
      case 'D': {
        uvcScanFlags |= kUVCTypeScanFlagShowInfo;
        break;
      }
      
      case 'd': {
        if ( ! uvcDevices ) uvcDevices = [[UVCController uvcControllers] retain];
        if ( uvcDevices && [uvcDevices count] ) {
          NSEnumerator    *eDevices = [uvcDevices objectEnumerator];
          UVCController   *device;
          unsigned long   deviceIndex = 0;
          NSMutableArray  *devList = [NSMutableArray array];

          while ( (device = [eDevices nextObject]) ) {
            UInt16      uvcVersion = [device uvcVersion];
            NSString    *verStr = [NSString stringWithFormat:@"%d.%02x", (short)(uvcVersion >> 8), (uvcVersion &0xFF)];
            
            NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithUnsignedLong:deviceIndex++], @"index",
                [NSNumber numberWithUnsignedShort:[device vendorId]], @"vendorId",
                [NSNumber numberWithUnsignedShort:[device productId]], @"productId",
                [NSNumber numberWithUnsignedInt:[device locationId]], @"locationId",
                verStr, @"uvcVersion",
                [device deviceName], @"name",
                nil];
            [devList addObject:d];
          }
          printJSON(devList);
        } else {
          printError(@"no UVC-capable devices available", ENODEV);
          rc = ENODEV;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'c': {
        if ( targetDevice ) {
          NSArray     *controlNames = [UVCController controlStrings];
          
          if ( controlNames && [controlNames count] ) {
            NSEnumerator  *eNames = [controlNames objectEnumerator];
            NSString      *name;
            NSMutableArray *list = [NSMutableArray array];
            
            while ( (name = [eNames nextObject]) ) {
              UVCControl  *control = [targetDevice controlWithName:name];
              if ( control ) [list addObject:name];
            }
            printJSON(list);
          } else {
            // No controls implemented
            printJSON([NSArray array]);
          }
        } else {
          NSArray     *controlNames = [UVCController controlStrings];
          if ( controlNames ) {
              printJSON(controlNames);
          }
        }
        break;
      }
      
      case '0': {
        targetDevice = nil;
        break;
      }
      
      case 'I': {
        if ( optarg && *optarg ) {
          char              *endPtr = NULL;
          unsigned long     deviceIndex = strtoul(optarg, &endPtr, 10);
          
          if ( endPtr > optarg ) {
            if ( ! uvcDevices ) uvcDevices = [[UVCController uvcControllers] retain];
            if ( uvcDevices ) {
              if ( deviceIndex < [uvcDevices count] ) {
                targetDevice = [uvcDevices objectAtIndex:deviceIndex];
                if ( ! targetDevice ) {
                  printError([NSString stringWithFormat:@"no UVC-capable device with the name \"%s\"", optarg], ENODEV);
                  rc = ENODEV;
                  if ( exitOnErrors ) goto cleanupAndExit;
                }
              } else {
                printError([NSString stringWithFormat:@"invalid device index: %lu", deviceIndex], EINVAL);
                rc = EINVAL;
                if ( exitOnErrors ) goto cleanupAndExit;
              }
            } else {
              printError(@"no UVC-capable devices available", ENODEV);
              rc = ENODEV;
              if ( exitOnErrors ) goto cleanupAndExit;
            }
          } else {
            printError([NSString stringWithFormat:@"invalid device index: %s", optarg], EINVAL);
            rc = EINVAL;
            if ( exitOnErrors ) goto cleanupAndExit;
          }
        } else {
          printError(@"missing argument to -I/--select-by-index", EINVAL);
          rc = EINVAL;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'N': {
        if ( optarg && *optarg ) {
          if ( ! uvcDevices ) uvcDevices = [[UVCController uvcControllers] retain];
          if ( uvcDevices ) {
            targetDevice = UVCUtilGetControllerWithName(uvcDevices, [NSString stringWithCString:optarg encoding:NSASCIIStringEncoding]);
            if ( ! targetDevice ) {
              printError([NSString stringWithFormat:@"no UVC-capable device with the name \"%s\"", optarg], ENODEV);
              rc = ENODEV;
              if ( exitOnErrors ) goto cleanupAndExit;
            }
          } else {
            printError(@"no UVC-capable devices available", ENODEV);
            rc = ENODEV;
            if ( exitOnErrors ) goto cleanupAndExit;
          }
        } else {
          printError(@"missing argument to -N/--select-by-name", EINVAL);
          rc = EINVAL;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'V': {
        if ( optarg && *optarg ) {
          unsigned short  vendorId, productId;
          int             nChar;
          
          if ( sscanf(optarg, "%hi:%n", &vendorId, &nChar) == 1 ) {
            if ( sscanf(optarg + nChar, "%hi", &productId) == 1 ) {
              if ( ! uvcDevices ) uvcDevices = [[UVCController uvcControllers] retain];
              if ( uvcDevices && [uvcDevices count] ) {
                targetDevice = UVCUtilGetControllerWithVendorAndProductId(uvcDevices, vendorId, productId);
                if ( ! targetDevice ) {
                  printError([NSString stringWithFormat:@"no UVC-capable device with vendor:product = 0x%04hx:0x%04hx", vendorId, productId], ENODEV);
                  rc = ENODEV;
                  if ( exitOnErrors ) goto cleanupAndExit;
                }
              } else {
                printError(@"no UVC-capable devices available", ENODEV);
                rc = ENODEV;
                if ( exitOnErrors ) goto cleanupAndExit;
              }
            } else {
              printError([NSString stringWithFormat:@"invalid product id: %s", optarg + nChar], EINVAL);
              rc = EINVAL;
              if ( exitOnErrors) goto cleanupAndExit;
            }
          } else {
            printError([NSString stringWithFormat:@"invalid vendor id: %s", optarg], EINVAL);
            rc = EINVAL;
            if ( exitOnErrors) goto cleanupAndExit;
          }
        } else {
          printError(@"missing argument to -V/--select-by-vendor-and-product-id", EINVAL);
          rc = EINVAL;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'L': {
        if ( optarg && *optarg ) {
          unsigned    locationId;
          
          if ( sscanf(optarg, "%i", &locationId) == 1 ) {
            if ( ! uvcDevices ) uvcDevices = [[UVCController uvcControllers] retain];
            if ( uvcDevices && [uvcDevices count] ) {
              targetDevice = UVCUtilGetControllerWithLocationId(uvcDevices, locationId);
              if ( ! targetDevice ) {
                printError([NSString stringWithFormat:@"no UVC-capable device with location = 0x%08x", locationId], ENODEV);
                rc = ENODEV;
                if ( exitOnErrors ) goto cleanupAndExit;
              }
            } else {
              printError(@"no UVC-capable devices available", ENODEV);
              rc = ENODEV;
              if ( exitOnErrors ) goto cleanupAndExit;
            }
          } else {
            printError([NSString stringWithFormat:@"invalid location id: %s", optarg], EINVAL);
            rc = EINVAL;
            if ( exitOnErrors) goto cleanupAndExit;
          }
        } else {
          printError(@"missing argument to -L/--select-by-location-id", EINVAL);
          rc = EINVAL;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'S': {
        if ( targetDevice ) {
          if ( optarg && *optarg ) {
            if ( (*optarg == '*') && (*(optarg + 1) == '\0') ) {
              NSArray     *controlNames = [UVCController controlStrings];
              NSMutableArray *list = [NSMutableArray array];
          
              if ( controlNames && [controlNames count] ) {
                NSEnumerator  *eNames = [controlNames objectEnumerator];
                NSString      *name;
                
                while ( (name = [eNames nextObject]) ) {
                  UVCControl  *control = [targetDevice controlWithName:name];
                  if ( control ) [list addObject:[control summaryDictionary]];
                }
              }
              printJSON(list);
            } else {
              long              controlNameLen = strlen(optarg);
              
              if ( controlNameLen ) {
                char            controlName[controlNameLen + 1];
                long            i = 0;
                  
                while ( i < controlNameLen ) {
                  controlName[i] = tolower(optarg[i]);
                  i++;
                }
                controlName[i] = '\0';
                  
                UVCControl      *control = [targetDevice controlWithName:[NSString stringWithCString:controlName encoding:NSASCIIStringEncoding]];
                    
                if ( control ) {
                  printJSON([control summaryDictionary]);
                } else {
                  printError([NSString stringWithFormat:@"invalid control name: %s", controlName], ENOENT);
                  rc = ENOENT;
                  if ( exitOnErrors ) goto cleanupAndExit;
                }
              }
            }
          } else {
            printError(@"missing argument to -S/--show option", EINVAL);
            rc = EINVAL;
            if ( exitOnErrors ) goto cleanupAndExit;
          }
        } else {
          printError(@"no target device selected", ENODEV);
          rc = ENODEV;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'o':
      case 'g': {
        if ( targetDevice ) {
          if ( optarg && *optarg ) {
            UVCControl      *control = [targetDevice controlWithName:[NSString stringWithCString:optarg encoding:NSASCIIStringEncoding]];
                
            if ( control ) {
              UVCValue      *currentValue = [control currentValue];
              
              if ( currentValue ) {
                if ( optCh == 'o' ) {
                  printJSON([currentValue jsonObject]);
                } else {
                  NSMutableDictionary *res = [NSMutableDictionary dictionary];
                  [res setObject:[control controlName] forKey:@"control"];
                  [res setObject:[currentValue jsonObject] forKey:@"value"];
                  printJSON(res);
                }
              } else {
                printError([NSString stringWithFormat:@"unable to read value of control: %s", optarg], EACCES);
                rc = EACCES;
                if ( exitOnErrors ) goto cleanupAndExit;
              }
            } else {
              printError([NSString stringWithFormat:@"invalid control name: %s", optarg], ENOENT);
              rc = ENOENT;
              if ( exitOnErrors ) goto cleanupAndExit;
            }
          } else {
            printError(@"missing argument to -g/--get/-o/--get-value option", EINVAL);
            rc = EINVAL;
            if ( exitOnErrors ) goto cleanupAndExit;
          }
        } else {
          printError(@"no target device selected", ENODEV);
          rc = ENODEV;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 'r': {
        if ( targetDevice ) {
          NSArray     *controlNames = [UVCController controlStrings];
          int         resetCount = 0;
          
          if ( controlNames && [controlNames count] ) {
            NSEnumerator  *eNames = [controlNames objectEnumerator];
            NSString      *name;
            
            while ( (name = [eNames nextObject]) ) {
              UVCControl  *control = [targetDevice controlWithName:name];
              
              if ( control && [control hasDefaultValue] ) {
                if ( ! [control resetToDefaultValue] ) {
                  printError([NSString stringWithFormat:@"unable to write default value to control %s", [name cStringUsingEncoding:NSASCIIStringEncoding]], EACCES);
                  rc = EACCES;
                  if ( exitOnErrors ) goto cleanupAndExit;
                } else {
                    resetCount++;
                }
              }
            }
          }
          printJSON([NSDictionary dictionaryWithObjectsAndKeys:
            @"success", @"status",
            [NSNumber numberWithInt:resetCount], @"reset-count",
            nil]);
        } else {
          printError(@"no target device selected", ENODEV);
          rc = ENODEV;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
      
      case 's': {
        if ( targetDevice ) {
          if ( optarg && *optarg ) {
            const char                  *valuePtr = strchr(optarg, '=');
            
            if ( valuePtr ) {
              long                        controlNameLen = valuePtr - optarg;
              
              valuePtr++;
              if ( controlNameLen ) {
                char                        controlName[controlNameLen + 1];
                long                        i = 0;
                
                while ( i < controlNameLen ) {
                  controlName[i] = tolower(optarg[i]);
                  i++;
                }
                controlName[i] = '\0';
                
                UVCControl      *control = [targetDevice controlWithName:[NSString stringWithCString:controlName encoding:NSASCIIStringEncoding]];
                  
                if ( control ) {
                  if ( [control setCurrentValueFromCString:valuePtr flags:uvcScanFlags] ) {
                    if ( ! [control writeFromCurrentValue] ) {
                      printError([NSString stringWithFormat:@"unable to write new value to control %s", controlName], EACCES);
                      rc = EACCES;
                      if ( exitOnErrors ) goto cleanupAndExit;
                    } else {
                        // Success
                        NSMutableDictionary *res = [NSMutableDictionary dictionary];
                        [res setObject:@"success" forKey:@"status"];
                        [res setObject:[control controlName] forKey:@"control"];
                        if ([control currentValue]) {
                            [res setObject:[[control currentValue] jsonObject] forKey:@"new-value"];
                        }
                        printJSON(res);
                    }
                  } else {
                    printError([NSString stringWithFormat:@"invalid value for control %s: %s", controlName, valuePtr], EINVAL);
                    rc = EINVAL;
                    if ( exitOnErrors ) goto cleanupAndExit;
                  }
                } else {
                  printError([NSString stringWithFormat:@"invalid control name: %s", controlName], ENOENT);
                  rc = ENOENT;
                  if ( exitOnErrors ) goto cleanupAndExit;
                }
              } else {
                printError([NSString stringWithFormat:@"missing control name: %s", optarg], EINVAL);
                rc = EINVAL;
                if ( exitOnErrors ) goto cleanupAndExit;
              }
            } else {
              printError([NSString stringWithFormat:@"no value provided with control name: %s", optarg], EINVAL);
              rc = EINVAL;
              if ( exitOnErrors ) goto cleanupAndExit;
            }
          } else {
            printError(@"missing argument to -s/--set option", EINVAL);
            rc = EINVAL;
            if ( exitOnErrors ) goto cleanupAndExit;
          }
        } else {
          printError(@"no target device selected", ENODEV);
          rc = ENODEV;
          if ( exitOnErrors ) goto cleanupAndExit;
        }
        break;
      }
  
    }
  }
}

cleanupAndExit:
  if ( uvcDevices ) [uvcDevices release];
  return rc;
}
