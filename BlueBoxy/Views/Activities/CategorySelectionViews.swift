//
//  CategorySelectionViews.swift
//  BlueBoxy
//
//  Category tab bar and drink sub-category selection views
//  Horizontal scrolling with category-specific styling
//

import SwiftUI

// MARK: - Category Tab Bar

struct CategoryTabBar: View {
    @Binding var selectedCategory: ActivityCategory
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ActivityCategory.allCases) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: ActivityCategory
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                
                // Label
                Text(category.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(category.color)
                            .matchedGeometryEffect(id: "category_background", in: namespace)
                            .shadow(color: category.color.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(category.color.opacity(0.1))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(category.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Drink Sub-Category Bar

struct DrinkSubCategoryBar: View {
    @Binding var selectedDrinkCategory: DrinkCategory
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DrinkCategory.allCases) { drinkCategory in
                        DrinkCategoryChip(
                            category: drinkCategory,
                            isSelected: selectedDrinkCategory == drinkCategory,
                            namespace: animation
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDrinkCategory = drinkCategory
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            // Divider
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.2))
        }
    }
}

// MARK: - Drink Category Chip

struct DrinkCategoryChip: View {
    let category: DrinkCategory
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Emoji icon
                Text(category.icon)
                    .font(.system(size: 16))
                
                // Label
                Text(category.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(category.color)
                            .matchedGeometryEffect(id: "drink_background", in: namespace)
                    } else {
                        Capsule()
                            .fill(category.color.opacity(0.1))
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(category.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Category Info Card

/// Optional info card to show category description
struct CategoryInfoCard: View {
    let category: ActivityCategory
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.title3)
                            .foregroundColor(category.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if !isExpanded {
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Sample activities
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examples:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(category.sampleActivities, id: \.self) { activity in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(category.color)
                                
                                Text(activity)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(category.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(category.color.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Previews

#Preview("Category Tab Bar") {
    VStack(spacing: 20) {
        CategoryTabBar(selectedCategory: .constant(.recommended))
        CategoryTabBar(selectedCategory: .constant(.dining))
        CategoryTabBar(selectedCategory: .constant(.drinks))
        Spacer()
    }
}

#Preview("Drink Sub-Category Bar") {
    VStack(spacing: 20) {
        DrinkSubCategoryBar(selectedDrinkCategory: .constant(.coffee))
        DrinkSubCategoryBar(selectedDrinkCategory: .constant(.alcohol))
        Spacer()
    }
}

#Preview("Category Info Card") {
    VStack(spacing: 12) {
        CategoryInfoCard(category: .recommended)
        CategoryInfoCard(category: .dining)
        CategoryInfoCard(category: .drinks)
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Full Category Experience") {
    VStack(spacing: 0) {
        CategoryTabBar(selectedCategory: .constant(.drinks))
        DrinkSubCategoryBar(selectedDrinkCategory: .constant(.coffee))
        
        ScrollView {
            VStack(spacing: 12) {
                CategoryInfoCard(category: .drinks)
                
                // Placeholder content
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}
