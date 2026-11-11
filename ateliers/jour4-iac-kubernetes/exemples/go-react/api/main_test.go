package main

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
)

// Test unitaire sans base ni cache : la fonction d'écriture JSON.
func TestWriteJSON(t *testing.T) {
	rec := httptest.NewRecorder()
	writeJSON(rec, 201, map[string]string{"service": service})

	if rec.Code != 201 {
		t.Fatalf("code attendu 201, obtenu %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("Content-Type attendu application/json, obtenu %q", ct)
	}
	var out map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("corps non JSON : %v", err)
	}
	if out["service"] != "api-go" {
		t.Fatalf("service attendu api-go, obtenu %q", out["service"])
	}
}
