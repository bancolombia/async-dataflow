import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatChipEditedEvent, MatChipInputEvent, MatChipsModule } from '@angular/material/chips';
import { MatCardModule } from '@angular/material/card';
import { SettingsService } from '../../services/settings.service';
import { Settings } from '../../models/settings.interface';
import { COMMA, ENTER } from '@angular/cdk/keycodes';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatCardModule, MatIconModule, MatChipsModule],
  templateUrl: './settings.component.html',
  styleUrl: './settings.component.css'
})
export class SettingsComponent implements OnInit, OnDestroy {
  readonly separatorKeysCodes = [ENTER, COMMA] as const;
  readonly addOnBlur = true;
  readonly allowedTransports = ['ws', 'sse'];
  constructor(private settingsProvider: SettingsService) { }
  settings?: Settings;

  ngOnInit(): void {
    this.settings = this.settingsProvider.load();
  }

  ngOnDestroy(): void {
    this.save();
  }

  save() {
    if (this.settings) {
      this.settingsProvider.save(this.settings);
    }
  }

  remove(transport: string) {
    if (this.settings) {
      this.settings.transports = this.settings.transports.filter(t => t !== transport);
    }
  }

  add(event: MatChipInputEvent) {
    if (this.settings) {
      const transport = event.value.trim();
      if (transport && this.allowedTransports.includes(transport)) {
        this.settings.transports.push(transport);
      }
    }
  }

  edit(transport: string, event: MatChipEditedEvent) {
    if (this.settings) {
      const newTransport = event.value.trim();
      if (transport && this.allowedTransports.includes(transport)) {
        this.settings.transports = this.settings.transports.map(t => t === transport ? newTransport : t);
      }
    }
  }

}
