import { TestBed } from '@angular/core/testing';

import { AsyncClientService } from './async-client.service';

describe('AsyncClientService', () => {
  let service: AsyncClientService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(AsyncClientService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
