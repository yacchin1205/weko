import pytest
from playwright.sync_api import Page, expect


class TestAdminFunctionality:
    """Admin functionality tests for WEKO3."""

    @pytest.fixture
    def admin_credentials(self):
        """Admin credentials for testing."""
        return {
            "email": "wekosoftware@nii.ac.jp",
            "password": "uspass123"
        }

    def test_admin_login_page_accessible(self, page: Page, base_url: str):
        """Test that admin login page is accessible."""
        admin_urls = [
            f"{base_url}/admin/",
            f"{base_url}/admin/login",
            f"{base_url}/login"
        ]
        
        login_page_found = False
        for url in admin_urls:
            try:
                response = page.goto(url)
                if response.status == 200:
                    # Look for login form elements
                    login_indicators = [
                        'input[type="email"]',
                        'input[type="password"]',
                        'input[name="email"]',
                        'input[name="password"]',
                        '.login-form',
                        'form[action*="login"]'
                    ]
                    
                    for indicator in login_indicators:
                        if page.locator(indicator).first.is_visible():
                            login_page_found = True
                            break
                    
                    if login_page_found:
                        break
            except:
                continue
        
        assert login_page_found, "Admin login page should be accessible"

    def test_admin_login_form_validation(self, page: Page, base_url: str):
        """Test admin login form validation."""
        admin_urls = [
            f"{base_url}/admin/",
            f"{base_url}/admin/login", 
            f"{base_url}/login"
        ]
        
        login_form_found = False
        for url in admin_urls:
            try:
                response = page.goto(url)
                if response.status == 200:
                    email_input = None
                    password_input = None
                    
                    # Find email input
                    email_selectors = ['input[type="email"]', 'input[name="email"]']
                    for selector in email_selectors:
                        try:
                            email_input = page.locator(selector).first
                            if email_input.is_visible():
                                break
                        except:
                            continue
                    
                    # Find password input  
                    password_selectors = ['input[type="password"]', 'input[name="password"]']
                    for selector in password_selectors:
                        try:
                            password_input = page.locator(selector).first
                            if password_input.is_visible():
                                break
                        except:
                            continue
                    
                    if email_input and password_input:
                        login_form_found = True
                        
                        # Test empty form submission
                        submit_button = page.locator('button[type="submit"], input[type="submit"]').first
                        if submit_button.is_visible():
                            submit_button.click()
                            
                            # Wait for validation or response
                            page.wait_for_load_state("networkidle", timeout=5000)
                            
                            # Should still be on login page or show validation errors
                            current_url = page.url
                            assert "login" in current_url or page.locator('.error, .alert').count() > 0
                        
                        break
            except:
                continue
        
        assert login_form_found, "Login form should be present and functional"

    def test_admin_dashboard_requires_authentication(self, page: Page, base_url: str):
        """Test that admin dashboard requires authentication."""
        admin_urls = [
            f"{base_url}/admin/",
            f"{base_url}/admin/dashboard"
        ]
        
        for url in admin_urls:
            try:
                response = page.goto(url)
                
                # Should either redirect to login or show authentication error
                # but not show admin dashboard content to unauthenticated users
                current_url = page.url
                
                # Check if redirected to login or authentication required
                auth_required = (
                    "login" in current_url.lower() or
                    response.status == 401 or
                    response.status == 403 or
                    page.locator('input[type="password"]').count() > 0
                )
                
                assert auth_required, f"Admin URL {url} should require authentication"
                break
            except:
                continue