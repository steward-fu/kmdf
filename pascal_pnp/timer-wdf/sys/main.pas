unit main;

interface
  uses
    DDDK;
    
  const
    DEV_NAME = '\Device\MyDriver';
    SYM_NAME = '\DosDevices\MyDriver';
    IOCTL_START = (FILE_DEVICE_UNKNOWN shl 16) or (FILE_ANY_ACCESS shl 14) or ($800 shl 2) or (METHOD_BUFFERED);
    IOCTL_STOP = (FILE_DEVICE_UNKNOWN shl 16) or (FILE_ANY_ACCESS shl 14) or ($801 shl 2) or (METHOD_BUFFERED);

  function __DriverEntry(pOurDriver:PDRIVER_OBJECT; pOurRegistry:PUNICODE_STRING):NTSTATUS; stdcall;

implementation
var
  cnt: ULONG;
  hTimer: WDFTIMER;

procedure OnTimer(Timer:WDFTIMER); stdcall;
begin
  cnt:= cnt + 1;
  DbgPrint('WdfTimer: %d', [cnt]);
end;

procedure IrpFileCreate(Device:WDFDEVICE; Request:WDFREQUEST; FileObject:WDFFILEOBJECT); stdcall;
begin
  DbgPrint('IrpFileCreate', []);
  WdfRequestComplete(Request, STATUS_SUCCESS);
end;

procedure IrpFileClose(FileObject:WDFFILEOBJECT); stdcall;
begin
  DbgPrint('IrpFileClose', []);
end;

procedure IrpIOCTL(Queue:WDFQUEUE; Request:WDFREQUEST; OutputBufferLength:ULONG; InputBufferLength:ULONG; IoControlCode:ULONG); stdcall;
var
  time: LARGE_INTEGER;
  
begin
  if IoControlCode = IOCTL_START then begin
    DbgPrint('IOCTL_START', []);
    cnt:= 0;
    time.HighPart:= -1;
    time.LowPart:= ULONG(-10000000);
    WdfTimerStart(hTimer, time.QuadPart);
  end
  else if IoControlCode = IOCTL_STOP then begin
    DbgPrint('IOCTL_STOP', []);
    WdfTimerStop(hTimer, False);
  end;
  WdfRequestComplete(Request, STATUS_SUCCESS);
end;

function AddDevice(pOurDriver:WDFDRIVER; pDeviceInit:PWDFDEVICE_INIT):NTSTATUS; stdcall;
var
  device: WDFDEVICE;
  suDevName: UNICODE_STRING;
  szSymName: UNICODE_STRING;
  timer_cfg: WDF_TIMER_CONFIG;
  file_cfg: WDF_FILEOBJECT_CONFIG;
  ioqueue_cfg: WDF_IO_QUEUE_CONFIG;
  timer_attribute: WDF_OBJECT_ATTRIBUTES;

begin
  WdfDeviceInitSetIoType(pDeviceInit, WdfDeviceIoBuffered);
  WDF_FILEOBJECT_CONFIG_INIT(@file_cfg, @IrpFileCreate, @IrpFileClose, Nil);
  WdfDeviceInitSetFileObjectConfig(pDeviceInit, @file_cfg, WDF_NO_OBJECT_ATTRIBUTES);
  
  RtlInitUnicodeString(@suDevName, DEV_NAME);
  RtlInitUnicodeString(@szSymName, SYM_NAME);
  WdfDeviceInitAssignName(pDeviceInit, @suDevName);
  WdfDeviceCreate(@pDeviceInit, WDF_NO_OBJECT_ATTRIBUTES, @device);
  WdfDeviceCreateSymbolicLink(device, @szSymName);
  
  WDF_TIMER_CONFIG_INIT_PERIODIC(@timer_cfg, @OnTimer, 1000);
  WDF_OBJECT_ATTRIBUTES_INIT(@timer_attribute);
  timer_attribute.ParentObject:= Pointer(device);
  WdfTimerCreate(@timer_cfg, @timer_attribute, @hTimer);
  
  WDF_IO_QUEUE_CONFIG_INIT_DEFAULT_QUEUE(@ioqueue_cfg, WdfIoQueueDispatchSequential);
  ioqueue_cfg.EvtIoDeviceControl:= @IrpIOCTL;
  Result:= WdfIoQueueCreate(device, @ioqueue_cfg, WDF_NO_OBJECT_ATTRIBUTES, WDF_NO_HANDLE);
end;

function __DriverEntry(pOurDriver:PDRIVER_OBJECT; pOurRegistry:PUNICODE_STRING):NTSTATUS; stdcall;
var
  config: WDF_DRIVER_CONFIG;
  
begin
  WDF_DRIVER_CONFIG_INIT(@config, AddDevice);
  WdfDriverCreate(pOurDriver, pOurRegistry, WDF_NO_OBJECT_ATTRIBUTES, @config, WDF_NO_HANDLE);
  Result:= STATUS_SUCCESS;
end;
end.
