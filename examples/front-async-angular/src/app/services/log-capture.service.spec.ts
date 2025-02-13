import { TestBed } from '@angular/core/testing';

import { LogCaptureService } from '../log-capture.service';

describe('LogCaptureService', () => {
  let service: LogCaptureService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(LogCaptureService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
